import { Controller } from "@hotwired/stimulus"

// Starts Active Storage Direct Upload only on pages that actually have
// a direct-upload form (the journal-entry form). @rails/activestorage
// is loaded with a *dynamic* import inside connect() — Stimulus
// eager-loads every controller module on every page, so a top-level
// import would pull Active Storage (and delay JS boot) onto pages
// that never upload. ActiveStorage.start() is idempotent (internal
// `started` guard), so reconnects are safe.
export default class extends Controller {
  connect() {
    import("@rails/activestorage").then((ActiveStorage) => {
      ActiveStorage.start()
    })
  }
}
