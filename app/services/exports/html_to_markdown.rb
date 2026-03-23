# frozen_string_literal: true

module Exports
  class HtmlToMarkdown
    def initialize(html, image_map: {})
      @html = html.to_s
      @image_map = image_map
    end

    def call
      processed = replace_action_text_attachments(@html)
      ReverseMarkdown.convert(processed, unknown_tags: :bypass)
    end

    private

    def replace_action_text_attachments(html)
      doc = Nokogiri::HTML.fragment(html)
      doc.css("action-text-attachment").each do |node|
        sgid = node["sgid"]
        blob = GlobalID::Locator.locate_signed(sgid)
        if blob && @image_map[blob.key]
          node.replace("![#{blob.filename}](#{@image_map[blob.key]})")
        elsif blob
          node.replace("![#{blob.filename}](#{blob.filename})")
        else
          node.replace("[attachment]")
        end
      end
      doc.to_html
    end
  end
end
