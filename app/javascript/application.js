// Configure your import map in config/importmap.rb. Read more: https://github.com/rails/importmap-rails
import "@hotwired/turbo-rails"
import "controllers"

import "trix"
import "@rails/actiontext"

// Active Storage Direct Upload: auto-binds to file inputs that carry
// data-direct-upload-url (form.file_field ..., direct_upload: true),
// PUTting bytes straight to SeaweedFS and submitting the signed_id.
import * as ActiveStorage from "@rails/activestorage"
ActiveStorage.start()
