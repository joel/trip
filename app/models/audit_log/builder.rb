# frozen_string_literal: true

class AuditLog
  # Turns a Rails.event structured event into a plain attribute Hash for
  # RecordAuditLogJob. Runs synchronously in the request thread (via
  # AuditLogSubscriber) so Current.* is populated. Returns nil to skip an
  # event. Reads are denormalised here so the row never needs a join later.
  class Builder
    VERB_PHRASES = {
      "created" => "created", "updated" => "updated",
      "deleted" => "deleted", "state_changed" => "changed the state of",
      "removed" => "removed", "images_added" => "added images to",
      "toggled" => "toggled an item in", "submitted" => "submitted",
      "approved" => "approved", "rejected" => "rejected",
      "sent" => "sent", "accepted" => "accepted"
    }.freeze

    def initialize(event)
      @name = event[:name].to_s
      @payload = event[:payload] || {}
      @entity, @verb = @name.split(".", 2)
    end

    def call
      subject = build_subject
      return nil unless subject

      actor = resolve_actor(subject)
      label = actor_label(actor)
      {
        trip_id: subject[:trip_id], actor_id: actor&.id,
        actor_label: label, action: @name,
        auditable_type: subject[:auditable_type],
        auditable_id: subject[:auditable_id],
        summary: summary(label, subject),
        metadata: build_metadata(subject),
        source: (Current.source || :web).to_s,
        request_id: Current.request_id,
        event_uid: event_uid(subject), occurred_at: Time.current
      }
    end

    private

    def build_subject
      builder = :"#{@entity}_subject"
      respond_to?(builder, true) ? send(builder) : nil
    end

    # --- per-entity subjects -------------------------------------------

    def trip_subject
      trip = Trip.find_by(id: @payload[:trip_id])
      name = trip&.name || @payload[:trip_name]
      base(@payload[:trip_id], trip_id: @payload[:trip_id],
                               record: trip, owner: trip&.created_by,
                               target: %(trip "#{name}"))
    end

    def journal_entry_subject
      entry = JournalEntry.find_by(id: @payload[:journal_entry_id])
      base(@payload[:journal_entry_id],
           trip_id: @payload[:trip_id], record: entry,
           owner: entry&.author,
           target: entry ? %(journal entry "#{entry.name}") : "a journal entry")
    end

    # Resolve trip via the (surviving) journal entry, not the comment:
    # comment.deleted is emitted after destroy!, so the comment row is
    # gone and only journal_entry_id is in the payload.
    def comment_subject
      comment = Comment.find_by(id: @payload[:comment_id])
      entry = JournalEntry.find_by(id: @payload[:journal_entry_id])
      base(@payload[:comment_id], trip_id: entry&.trip_id, record: comment,
                                  owner: comment&.user, target: "a comment")
    end

    # Resolve trip from the reactable in the payload, not the reaction:
    # reaction.removed is emitted after destroy!, so the reaction row is
    # gone. Mirrors Reaction#trip.
    def reaction_subject
      reaction = Reaction.find_by(id: @payload[:reaction_id])
      base(@payload[:reaction_id], trip_id: reaction_trip_id,
                                   record: reaction, owner: reaction&.user,
                                   target: "a reaction")
    end

    def reaction_trip_id
      case @payload[:reactable_type]
      when "Trip"
        @payload[:reactable_id]
      when "JournalEntry"
        JournalEntry.find_by(id: @payload[:reactable_id])&.trip_id
      when "Comment"
        Comment.find_by(id: @payload[:reactable_id])
               &.journal_entry&.trip_id
      end
    end

    def checklist_subject
      list = Checklist.find_by(id: @payload[:checklist_id])
      name = list&.name
      base(@payload[:checklist_id], trip_id: @payload[:trip_id],
                                    record: list,
                                    target: name ? %(checklist "#{name}") : "a checklist")
    end

    def checklist_item_subject
      list = Checklist.find_by(id: @payload[:checklist_id])
      base(@payload[:checklist_item_id], trip_id: list&.trip_id,
                                         record: list,
                                         target: list ? %(checklist "#{list.name}") : "a checklist")
    end

    def export_subject
      base(@payload[:export_id], trip_id: @payload[:trip_id],
                                 owner: User.find_by(id: @payload[:user_id]),
                                 target: "a #{@payload[:format]} export")
    end

    def access_request_subject
      base(@payload[:access_request_id], trip_id: nil,
                                         owner: User.find_by(id: @payload[:reviewer_id]),
                                         target: "access request for #{@payload[:email]}")
    end

    def invitation_subject
      base(@payload[:invitation_id], trip_id: nil,
                                     target: "an invitation to #{@payload[:email]}")
    end

    def trip_membership_subject
      member = User.find_by(id: @payload[:user_id])
      base(@payload[:trip_membership_id], trip_id: @payload[:trip_id],
                                          target: "#{member&.name || "a member"} from the trip")
    end

    # auditable_type is the entity class name (trip_membership -> TripMembership)
    def base(id, trip_id:, target:, record: nil, owner: nil)
      { auditable_type: @entity.classify, auditable_id: id,
        trip_id: trip_id, auditable: record, owner: owner, target: target }
    end

    # --- actor ----------------------------------------------------------

    def resolve_actor(subject)
      User.find_by(id: @payload[:actor_id]) ||
        Current.actor ||
        subject[:owner]
    end

    def actor_label(actor)
      return "System" unless actor

      agent = Agent.find_by(user_id: actor.id)
      return "#{agent.name} (agent)" if agent

      actor.name.presence || actor.email
    end

    # --- summary & metadata --------------------------------------------

    def summary(label, subject)
      "#{label} #{verb_phrase} #{subject[:target]}#{suffix}".squish
    end

    def verb_phrase
      VERB_PHRASES.fetch(@verb, @verb.to_s.tr("_", " "))
    end

    def suffix
      return changes_suffix if @payload[:changes].present?
      return state_suffix if @verb == "state_changed"

      ""
    end

    def changes_suffix
      parts = @payload[:changes].first(3).map do |field, (old, new)|
        %(#{field.to_s.humanize}: "#{clip(old)}" → "#{clip(new)}")
      end
      " — #{parts.join(", ")}"
    end

    def state_suffix
      " — #{@payload[:from_state].to_s.humanize} → " \
        "#{@payload[:to_state].to_s.humanize}"
    end

    def build_metadata(subject)
      {
        "changes" => @payload[:changes],
        "from_state" => @payload[:from_state],
        "to_state" => @payload[:to_state],
        "target_name" => subject[:target]
      }.compact
    end

    def clip(value)
      str = value.to_s
      str.length > 80 ? "#{str[0, 77]}..." : str
    end

    def event_uid(subject)
      key = subject[:auditable_id] || @payload.values.first
      base = Current.request_id || SecureRandom.uuid
      "#{base}:#{@name}:#{key}"
    end
  end
end
