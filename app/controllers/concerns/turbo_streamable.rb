# frozen_string_literal: true

module TurboStreamable
  extend ActiveSupport::Concern

  included do
    include ActionView::RecordIdentifier
  end

  private

  def phlex_to_html(component)
    render_to_string(component, layout: false)
  end

  def stream_replace(target, component)
    turbo_stream.replace(target, html: phlex_to_html(component))
  end

  def stream_append(target, component)
    turbo_stream.append(target, html: phlex_to_html(component))
  end

  def stream_remove(target)
    turbo_stream.remove(target)
  end
end
