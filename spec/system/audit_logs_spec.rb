# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Trip Activity feed" do
  let(:admin) { create(:user, :superadmin) }
  let(:contributor_user) { create(:user) }
  let(:viewer_user) { create(:user) }
  let(:trip) { create(:trip, name: "Iceland", created_by: admin) }

  before do
    create(:trip_membership, trip: trip, user: contributor_user,
                             role: :contributor)
    create(:trip_membership, trip: trip, user: viewer_user,
                             role: :viewer)
  end

  it "shows the Activity link and feed to a contributor" do
    create(:audit_log, trip: trip, actor_label: "Joel",
                       summary: 'Joel created trip "Iceland"')
    login_as(user: contributor_user)

    visit trip_path(trip)
    click_on "Activity"

    expect(page).to have_text("Activity")
    expect(page).to have_text('Joel created trip "Iceland"')
  end

  it "renders an edit diff and a source badge for agent rows" do
    agent = create(:agent, name: "Marée")
    create(:audit_log, :with_changes, trip: trip,
                                      actor: agent.user,
                                      actor_label: "Marée (agent)",
                                      source: :mcp,
                                      summary: "Marée (agent) updated " \
                                               'trip "Iceland"')
    login_as(user: admin)

    visit trip_audit_logs_path(trip)

    expect(page).to have_text("Name:")
    expect(page).to have_text("Old Name")
    expect(page).to have_text("New Name")
    # The source badge is rendered with a Tailwind `uppercase` class;
    # the Selenium driver reports the CSS-transformed visible text.
    expect(page).to have_text("AGENT")
    expect(page).to have_text('Marée (agent) updated trip "Iceland"')
  end

  it "hides the Activity link from a viewer and 404s direct access" do
    login_as(user: viewer_user)

    visit trip_path(trip)
    expect(page).to have_text(trip.name)
    expect(page).to have_no_link("Activity")

    # The controller does `head :not_found` for viewers. `page.status_code`
    # is unsupported by the Selenium driver, so assert the feed chrome is
    # absent (the page did not render) in a driver-agnostic way.
    visit trip_audit_logs_path(trip)
    expect(page).to have_current_path(trip_audit_logs_path(trip))
    expect(page).to have_no_text("Show low-signal")
    expect(page).to have_no_text("Back to trip")
  end

  it "groups low-signal rows behind a toggle" do
    create(:audit_log, trip: trip, summary: "A new journal entry")
    create(:audit_log, :low_signal, trip: trip,
                                    summary: "Someone reacted")
    login_as(user: admin)

    visit trip_audit_logs_path(trip)
    expect(page).to have_text("A new journal entry")
    expect(page).to have_no_text("Someone reacted")

    click_on "Show low-signal"
    expect(page).to have_text("Someone reacted")
  end

  context "when an action is performed through the UI" do
    around do |example|
      adapter = ActiveJob::Base.queue_adapter
      ActiveJob::Base.queue_adapter = :inline
      example.run
      ActiveJob::Base.queue_adapter = adapter
    end

    it "logs a trip edit performed through the UI" do
      login_as(user: admin)

      visit edit_trip_path(trip)
      fill_in "Name", with: "Norway"
      click_on "Update Trip"
      expect(page).to have_text("Trip updated")

      visit trip_audit_logs_path(trip)
      expect(page).to have_text("updated trip")
      expect(page).to have_text('Name: "Iceland" → "Norway"')
    end
  end
end
