# frozen_string_literal: true

class ChecklistsController < ApplicationController
  before_action :require_authenticated_user!
  before_action :set_trip
  before_action :set_checklist, only: %i[show edit update destroy]
  before_action :authorize_checklist!

  def index
    @checklists = @trip.checklists.ordered
    render Views::Checklists::Index.new(
      trip: @trip, checklists: @checklists
    )
  end

  def show
    render Views::Checklists::Show.new(
      trip: @trip, checklist: @checklist
    )
  end

  def new
    @checklist = @trip.checklists.new
    render Views::Checklists::New.new(
      trip: @trip, checklist: @checklist
    )
  end

  def edit
    render Views::Checklists::Edit.new(
      trip: @trip, checklist: @checklist
    )
  end

  def create
    result = Checklists::Create.new.call(
      params: checklist_params, trip: @trip
    )
    case result
    in Dry::Monads::Success(checklist)
      redirect_to [@trip, checklist],
                  notice: "Checklist created."
    in Dry::Monads::Failure(errors)
      @checklist = @trip.checklists.new(checklist_params)
      merge_errors(@checklist, errors)
      render Views::Checklists::New.new(
        trip: @trip, checklist: @checklist
      ), status: :unprocessable_content
    end
  end

  def update
    result = Checklists::Update.new.call(
      checklist: @checklist, params: checklist_params
    )
    case result
    in Dry::Monads::Success(checklist)
      redirect_to [@trip, checklist],
                  notice: "Checklist updated."
    in Dry::Monads::Failure(errors)
      merge_errors(@checklist, errors)
      render Views::Checklists::Edit.new(
        trip: @trip, checklist: @checklist
      ), status: :unprocessable_content
    end
  end

  def destroy
    Checklists::Delete.new.call(checklist: @checklist)
    redirect_to trip_checklists_path(@trip),
                notice: "Checklist deleted.", status: :see_other
  end

  private

  def set_trip
    @trip = Trip.find(params[:trip_id])
  end

  def set_checklist
    @checklist = @trip.checklists.find(params[:id])
  end

  def authorize_checklist!
    authorize!(@checklist || @trip.checklists.new)
  end

  def checklist_params
    params.expect(checklist: [:name])
  end

  def merge_errors(record, errors)
    record.errors.merge!(errors) if errors.respond_to?(:each)
  end
end
