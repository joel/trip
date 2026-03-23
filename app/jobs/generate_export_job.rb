# frozen_string_literal: true

class GenerateExportJob < ApplicationJob
  include ActiveJob::Continuable

  queue_as :default

  def perform(export_id)
    @export = Export.find(export_id)

    step :mark_processing do
      @export.processing!
    end

    step :generate_file do
      @tempfile = generator.call
    end

    step :attach_file do
      @export.file.attach(
        io: File.open(@tempfile.path),
        filename: export_filename,
        content_type: content_type
      )
      @export.completed!
      @tempfile.close!
    end

    step :notify_user do
      send_notification
    end
  rescue StandardError => e
    @export&.failed! unless @export&.completed? || @export&.failed?
    raise e
  end

  private

  def send_notification
    ExportMailer.export_ready(@export.id).deliver_now
  rescue StandardError => e
    Rails.logger.error(
      "Export #{@export.id} notification failed: #{e.message}"
    )
  end

  def generator
    case @export.format
    when "markdown"
      Exports::MarkdownGenerator.new(@export)
    when "epub"
      Exports::EpubGenerator.new(@export)
    end
  end

  def export_filename
    trip_slug = @export.trip.name.parameterize
    case @export.format
    when "markdown" then "#{trip_slug}.zip"
    when "epub" then "#{trip_slug}.epub"
    end
  end

  def content_type
    case @export.format
    when "markdown" then "application/zip"
    when "epub" then "application/epub+zip"
    end
  end
end
