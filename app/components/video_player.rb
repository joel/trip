# frozen_string_literal: true

module Components
  # Inline player for one JournalEntryVideo, rendered by status:
  #   ready      -> <video> (poster-first, playsinline, controls,
  #                 muted; the video-player Stimulus controller adds
  #                 IntersectionObserver play/pause and respects
  #                 reduced-motion / Save-Data before autoplaying)
  #   pending/   -> a poster/placeholder ("Optimizing video…") so the
  #   processing    card still renders with no broken <video>
  #   failed     -> a small, non-blocking "Video unavailable" notice
  class VideoPlayer < Components::Base
    def initialize(video:)
      @video = video
    end

    def view_template
      case @video.status.to_s
      when "ready" then render_player
      when "failed" then render_unavailable
      else render_processing
      end
    end

    private

    def render_player
      div(
        class: "relative overflow-hidden rounded-xl " \
               "bg-[var(--ha-surface-high)]",
        style: aspect_style
      ) do
        video(
          class: "h-full w-full object-contain",
          poster: url(@video.poster),
          controls: true,
          playsinline: true,
          muted: true,
          loop: false,
          preload: "metadata",
          data: { controller: "video-player" }
        ) do
          source(src: url(@video.web), type: "video/mp4")
        end
      end
    end

    def render_processing
      placeholder("Optimizing video…")
    end

    def render_unavailable
      placeholder("Video unavailable")
    end

    def placeholder(text)
      div(
        class: "flex items-center justify-center rounded-xl " \
               "bg-[var(--ha-surface-high)] " \
               "text-sm text-[var(--ha-on-surface-variant)]",
        style: aspect_style
      ) { plain text }
    end

    def aspect_style
      w = @video.width.to_i
      h = @video.height.to_i
      return "aspect-ratio: 16/9;" if w <= 0 || h <= 0

      "aspect-ratio: #{w}/#{h};"
    end

    def url(attachment)
      view_context.url_for(attachment)
    rescue StandardError, LoadError
      ""
    end
  end
end
