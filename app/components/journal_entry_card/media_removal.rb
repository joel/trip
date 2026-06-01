# frozen_string_literal: true

module Components
  class JournalEntryCard < Components::Base
    # Per-item media remove overlays (Phase 26). Each image tile / video player
    # gets a "Remove" button (shown on hover/focus) that soft-deletes the one
    # item; it is restorable from the Activity feed. Gated on the entry's
    # destroy? permission, mirroring the entry Delete affordance.
    module MediaRemoval
      # Always visible (no hover-only control — a11y + touch + testability),
      # subdued until hover/focus.
      OVERLAY_CLASS = "absolute top-2 right-2 z-10 opacity-80 " \
                      "hover:opacity-100 focus-within:opacity-100 " \
                      "motion-safe:transition-opacity"

      private

      def render_remove_video(video)
        return unless can_remove_media?

        remove_overlay_button(
          view_context.trip_journal_entry_video_path(@trip, @entry, video),
          "Remove this video? You can restore it from Activity.",
          OVERLAY_CLASS
        )
      end

      def render_remove_image(image)
        return unless can_remove_media?

        remove_overlay_button(
          view_context.trip_journal_entry_image_path(
            @trip, @entry, image.blob.signed_id
          ),
          "Remove this photo? You can restore it from Activity.",
          OVERLAY_CLASS
        )
      end

      def remove_overlay_button(path, confirm, form_class)
        button_to(
          "Remove", path, method: :delete,
                          class: "ha-button ha-button-danger text-xs",
                          form: { class: form_class,
                                  data: { turbo_confirm: confirm } }
        )
      end

      # Whoever may delete the entry may remove its individual media.
      def can_remove_media?
        view_context.allowed_to?(:destroy?, @entry)
      end
    end
  end
end
