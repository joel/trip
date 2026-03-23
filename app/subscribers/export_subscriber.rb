# frozen_string_literal: true

class ExportSubscriber
  def emit(event)
    case event[:name]
    when "export.requested"
      GenerateExportJob.perform_later(
        event[:payload][:export_id]
      )
    end
  end
end
