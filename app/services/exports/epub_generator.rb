# frozen_string_literal: true

module Exports
  class EpubGenerator
    def initialize(export)
      @export = export
      @trip = export.trip
    end

    def call
      tempfile = Tempfile.new(
        ["export_#{@export.id}", ".epub"]
      )
      generate_epub(tempfile.path)
      tempfile
    end

    private

    def generate_epub(path)
      entries = @trip.journal_entries
                     .chronological
                     .includes(:author, rich_text_body: :embeds)

      book = GEPUB::Book.new
      book.identifier = "trip-#{@trip.id}"
      book.title = @trip.name
      book.language = "en"

      image_resources = add_images(book, entries)
      add_chapters(book, entries, image_resources)

      book.generate_epub(path)
    end

    def add_images(book, entries)
      resources = {}
      entries.each do |entry|
        collect_blobs(entry).each do |blob|
          next if resources[blob.key]

          blob.open do |file|
            media_type = blob.content_type
            href = "images/#{blob.filename}"
            book.add_item(href, content: file,
                                media_type: media_type)
            resources[blob.key] = href
          end
        end
      end
      resources
    end

    def add_chapters(book, entries, image_resources)
      entries.each_with_index do |entry, idx|
        body = process_html(entry, image_resources)
        xhtml = XhtmlWrapper.new(
          title: entry.name, body_html: body
        ).call

        item = book.add_item(
          "chapter_#{idx + 1}.xhtml"
        )
        item.add_content(StringIO.new(xhtml))
        book.spine << item
      end
    end

    def process_html(entry, image_resources)
      html = entry.body.to_s
      doc = Nokogiri::HTML.fragment(html)

      doc.css("action-text-attachment").each do |node|
        sgid = node["sgid"]
        blob = GlobalID::Locator.locate_signed(sgid)
        if blob && image_resources[blob.key]
          img = Nokogiri::XML::Node.new("img", doc)
          img["src"] = image_resources[blob.key]
          img["alt"] = blob.filename.to_s
          node.replace(img)
        else
          node.remove
        end
      end

      <<~HTML
        <h1>#{CGI.escapeHTML(entry.name)}</h1>
        <p><em>#{entry.entry_date} — #{CGI.escapeHTML(entry.author.name || entry.author.email)}</em></p>
        #{doc.to_html}
      HTML
    end

    def collect_blobs(entry)
      rich_text_blobs(entry) + attachment_blobs(entry)
    end

    def rich_text_blobs(entry)
      return [] unless entry.body&.embeds&.any?

      entry.body.embeds.filter_map(&:blob)
    end

    def attachment_blobs(entry)
      return [] unless entry.images.attached?

      entry.images.filter_map(&:blob)
    end
  end
end
