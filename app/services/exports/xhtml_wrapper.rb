# frozen_string_literal: true

module Exports
  class XhtmlWrapper
    def initialize(title:, body_html:)
      @title = title
      @body_html = body_html
    end

    def call
      <<~XHTML
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE html>
        <html xmlns="http://www.w3.org/1999/xhtml">
        <head>
          <title>#{escape(@title)}</title>
        </head>
        <body>
          #{@body_html}
        </body>
        </html>
      XHTML
    end

    private

    def escape(text)
      CGI.escapeHTML(text.to_s)
    end
  end
end
