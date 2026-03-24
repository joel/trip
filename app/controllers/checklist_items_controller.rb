# frozen_string_literal: true

class ChecklistItemsController < ApplicationController
  before_action :require_authenticated_user!
  before_action :set_trip
  before_action :set_checklist
  before_action :set_checklist_item, only: %i[toggle destroy]
  before_action :authorize_checklist_item!

  def create
    section = @checklist.checklist_sections.find(
      params[:checklist_item][:checklist_section_id]
    )
    result = ChecklistItems::Create.new.call(
      params: checklist_item_params, checklist_section: section
    )
    case result
    in Dry::Monads::Success(_item)
      redirect_to [@trip, @checklist],
                  notice: "Item added."
    in Dry::Monads::Failure(_errors)
      redirect_to [@trip, @checklist],
                  alert: "Could not add item."
    end
  end

  def toggle
    ChecklistItems::Toggle.new.call(
      checklist_item: @checklist_item
    )
    @checklist_item.reload

    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.replace(
          dom_id(@checklist_item),
          html: render_to_string(
            Components::ChecklistItemRow.new(
              trip: @trip, checklist: @checklist,
              item: @checklist_item
            ), layout: false
          )
        )
      end
      format.html { redirect_to [@trip, @checklist] }
    end
  end

  def destroy
    @checklist_item.destroy!
    redirect_to [@trip, @checklist],
                notice: "Item removed.", status: :see_other
  end

  private

  def set_trip
    @trip = Trip.find(params[:trip_id])
  end

  def set_checklist
    @checklist = @trip.checklists.find(params[:checklist_id])
  end

  def set_checklist_item
    @checklist_item = ChecklistItem
                      .joins(:checklist_section)
                      .where(checklist_sections: {
                               checklist_id: @checklist.id
                             })
                      .find(params[:id])
  end

  def authorize_checklist_item!
    item = @checklist_item || @checklist.checklist_sections
                                        .first
                                        &.checklist_items
                                        &.new
    authorize!(item || ChecklistItem.new(
      checklist_section: @checklist.checklist_sections.new
    ))
  end

  def checklist_item_params
    params.expect(checklist_item: [:content])
  end
end
