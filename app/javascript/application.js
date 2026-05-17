// Configure your import map in config/importmap.rb. Read more: https://github.com/rails/importmap-rails
import "@hotwired/turbo-rails"
import "controllers"

import "trix"
import "@rails/actiontext"
// Active Storage Direct Upload is started by the direct-upload
// Stimulus controller (scoped to the journal-entry form), not
// globally, so it stays off every other page's JS-boot path.
