# frozen_string_literal: true

require "rails_helper"

RSpec.describe "/trips/:trip_id/exports" do
  let!(:admin) { create(:user, :superadmin) }
  let!(:trip) { create(:trip, created_by: admin) }

  before { stub_current_user(admin) }

  describe "GET index" do
    it "renders successfully" do
      get trip_exports_path(trip)
      expect(response).to have_http_status(:ok)
    end
  end

  describe "GET new" do
    it "renders the new export form" do
      get new_trip_export_path(trip)
      expect(response).to have_http_status(:ok)
    end
  end

  describe "POST create" do
    it "creates an export" do
      expect do
        post trip_exports_path(trip),
             params: { export: { format: "markdown" } }
      end.to change(Export, :count).by(1)
    end

    it "redirects to show page" do
      post trip_exports_path(trip),
           params: { export: { format: "markdown" } }
      expect(response).to redirect_to(
        trip_export_path(trip, Export.last)
      )
    end
  end

  describe "GET show" do
    it "renders export details" do
      export = create(:export, trip: trip, user: admin)
      get trip_export_path(trip, export)
      expect(response).to have_http_status(:ok)
    end
  end

  describe "GET download" do
    it "redirects when not completed" do
      export = create(:export, trip: trip, user: admin)
      get download_trip_export_path(trip, export)
      expect(response).to redirect_to(
        trip_export_path(trip, export)
      )
    end
  end

  describe "authorization" do
    let(:outsider) { create(:user) }

    it "denies non-member" do
      stub_current_user(outsider)
      get trip_exports_path(trip)
      expect(response).to have_http_status(:forbidden)
    end

    it "denies export creation on cancelled trip" do
      member = create(:user)
      create(:trip_membership, trip: trip, user: member,
                               role: :contributor)
      stub_current_user(member)
      trip.update!(state: :cancelled)
      post trip_exports_path(trip),
           params: { export: { format: "markdown" } }
      expect(response).to have_http_status(:forbidden)
    end
  end
end
