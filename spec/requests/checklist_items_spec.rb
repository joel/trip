# frozen_string_literal: true

require "rails_helper"

RSpec.describe "/trips/:trip_id/checklists/:id/checklist_items" do
  let!(:admin) { create(:user, :superadmin) }
  let!(:trip) { create(:trip, created_by: admin) }
  let!(:checklist) { create(:checklist, trip: trip) }
  let!(:section) do
    create(:checklist_section, checklist: checklist)
  end

  before { stub_current_user(admin) }

  describe "POST create" do
    it "creates an item" do
      expect do
        post trip_checklist_checklist_items_path(
          trip, checklist
        ), params: {
          checklist_item: {
            content: "Passport",
            checklist_section_id: section.id
          }
        }
      end.to change(ChecklistItem, :count).by(1)
    end
  end

  describe "PATCH toggle" do
    it "toggles item completion" do
      item = create(:checklist_item, checklist_section: section)
      patch toggle_trip_checklist_checklist_item_path(
        trip, checklist, item
      )
      expect(item.reload).to be_completed
    end
  end

  describe "DELETE destroy" do
    it "deletes an item" do
      item = create(:checklist_item, checklist_section: section)
      expect do
        delete trip_checklist_checklist_item_path(
          trip, checklist, item
        )
      end.to change(ChecklistItem, :count).by(-1)
    end
  end

  describe "authorization" do
    let(:viewer_user) { create(:user) }

    before do
      create(:trip_membership, trip: trip, user: viewer_user,
                               role: :viewer)
      stub_current_user(viewer_user)
    end

    it "denies viewer to toggle" do
      item = create(:checklist_item, checklist_section: section)
      patch toggle_trip_checklist_checklist_item_path(
        trip, checklist, item
      )
      expect(response).to have_http_status(:forbidden)
    end
  end
end
