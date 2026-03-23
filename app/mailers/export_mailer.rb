# frozen_string_literal: true

class ExportMailer < ApplicationMailer
  def export_ready(export_id)
    @export = Export.find_by(id: export_id)
    return unless @export

    @trip = @export.trip
    @user = @export.user

    mail(
      to: @user.email,
      subject: "Your #{@export.format} export of " \
               "#{@trip.name} is ready"
    )
  end
end
