# frozen_string_literal: true

class ChecklistSectionsController < ApplicationController
  before_action :require_authenticated_user!
  before_action :set_trip
  before_action :set_checklist
  before_action :authorize_checklist!

  def create
    @checklist.checklist_sections.create!(
      name: params[:checklist_section][:name]
    )
    redirect_to [@trip, @checklist], notice: "Section added."
  rescue ActiveRecord::RecordInvalid
    redirect_to [@trip, @checklist], alert: "Could not add section."
  end

  def destroy
    section = @checklist.checklist_sections.find(params[:id])
    section.destroy!
    redirect_to [@trip, @checklist],
                notice: "Section removed.", status: :see_other
  end

  private

  def set_trip
    @trip = Trip.find(params[:trip_id])
  end

  def set_checklist
    @checklist = @trip.checklists.find(params[:checklist_id])
  end

  def authorize_checklist!
    authorize!(@checklist)
  end
end
