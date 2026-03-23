# frozen_string_literal: true

module Exports
  class MarkdownGenerator
    def initialize(export)
      @export = export
      @trip = export.trip
    end

    def call
      tempfile = Tempfile.new(
        ["export_#{@export.id}", ".zip"]
      )
      generate_zip(tempfile.path)
      tempfile
    end

    private

    def generate_zip(path)
      entries = @trip.journal_entries
                     .chronological
                     .includes(:author, rich_text_body: :embeds)
      image_blobs = collect_image_blobs(entries)

      Zip::OutputStream.open(path) do |zip|
        write_index(zip)
        entries.each { |entry| write_entry(zip, entry, image_blobs) }
        write_images(zip, image_blobs)
      end
    end

    def write_index(zip)
      zip.put_next_entry("_index.md")
      zip.write(index_content)
    end

    def index_content
      <<~MARKDOWN
        ---
        title: "#{@trip.name}"
        state: #{@trip.state}
        start_date: #{@trip.effective_start_date}
        end_date: #{@trip.effective_end_date}
        exported_at: #{Time.current.iso8601}
        ---

        # #{@trip.name}

        #{@trip.description}
      MARKDOWN
    end

    def write_entry(zip, entry, image_blobs)
      slug = entry_slug(entry)
      image_map = build_image_map(entry, image_blobs)
      body_md = HtmlToMarkdown.new(
        entry.body&.to_s, image_map: image_map
      ).call

      zip.put_next_entry("#{slug}.md")
      zip.write(entry_content(entry, body_md))
    end

    def entry_content(entry, body_md)
      <<~MARKDOWN
        ---
        title: "#{entry.name}"
        date: #{entry.entry_date}
        author: "#{entry.author.name || entry.author.email}"
        location: "#{entry.location_name}"
        latitude: #{entry.latitude}
        longitude: #{entry.longitude}
        ---

        # #{entry.name}

        #{body_md}
      MARKDOWN
    end

    def write_images(zip, image_blobs)
      image_blobs.each do |blob|
        zip.put_next_entry("assets/#{blob.filename}")
        blob.open { |file| zip.write(file.read) }
      end
    end

    def collect_image_blobs(entries)
      entries.flat_map do |entry|
        blobs_from_rich_text(entry) +
          blobs_from_attachments(entry)
      end.uniq(&:id)
    end

    def blobs_from_rich_text(entry)
      return [] unless entry.body&.embeds&.any?

      entry.body.embeds.filter_map(&:blob)
    end

    def blobs_from_attachments(entry)
      return [] unless entry.images.attached?

      entry.images.filter_map(&:blob)
    end

    def build_image_map(entry, image_blobs)
      map = {}
      blobs_from_rich_text(entry).each do |blob|
        map[blob.key] = "assets/#{blob.filename}" if image_blobs.include?(blob)
      end
      map
    end

    def entry_slug(entry)
      date = entry.entry_date&.strftime("%Y-%m-%d") || "undated"
      name = entry.name.parameterize
      "#{date}-#{name}"
    end
  end
end
