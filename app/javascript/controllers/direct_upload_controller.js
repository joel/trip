import { Controller } from "@hotwired/stimulus"

// Active Storage Direct Upload + progress UI for the journal-entry
// form. Bytes flow browser → SeaweedFS over the public HTTPS endpoint
// (Phase 2 of #44); the form was previously frozen with no feedback
// for the duration of the upload — fix tracked in #175. This
// controller:
//
//   1. Lazy-loads @rails/activestorage on connect (Stimulus eager-
//      loads controller modules; a top-level import would pull AS
//      onto every page).
//   2. On form submit, shows a modal overlay that visually blocks
//      the form (fixed inset-0 z-50). We deliberately do NOT set
//      disabled on the form fields — browsers exclude disabled
//      fields from the submitted FormData, which would break the
//      submit (only the file inputs would arrive). The overlay
//      itself prevents the user clicking anything underneath.
//   3. Listens to direct-upload:start/progress/end/error events that
//      @rails/activestorage dispatches on the form, aggregates per-
//      file progress (size-weighted), and updates the overlay.
//   4. Switches the overlay label from "Uploading…" to "Saving
//      entry…" once all PUTs finish and Rails takes over the submit.
//   5. On error: keeps the overlay visible (the error message lives
//      inside it), surfaces the message, and exposes a Dismiss
//      button so the user can close the overlay and retry without a
//      page reload.
//
// ActiveStorage.start() is idempotent — reconnects are safe.
export default class extends Controller {
  static targets = ["overlay", "label", "progress", "detail", "error", "dismiss"]

  connect() {
    this.uploads = new Map()
    this._submitting = false

    import("@rails/activestorage").then((ActiveStorage) => {
      ActiveStorage.start()
    })

    this._onSubmit = this._onSubmit.bind(this)
    this._onStart = this._onStart.bind(this)
    this._onProgress = this._onProgress.bind(this)
    this._onEnd = this._onEnd.bind(this)
    this._onError = this._onError.bind(this)

    this.element.addEventListener("submit", this._onSubmit)
    this.element.addEventListener("direct-upload:start", this._onStart)
    this.element.addEventListener("direct-upload:progress", this._onProgress)
    this.element.addEventListener("direct-upload:end", this._onEnd)
    this.element.addEventListener("direct-upload:error", this._onError)
  }

  disconnect() {
    this.element.removeEventListener("submit", this._onSubmit)
    this.element.removeEventListener("direct-upload:start", this._onStart)
    this.element.removeEventListener("direct-upload:progress", this._onProgress)
    this.element.removeEventListener("direct-upload:end", this._onEnd)
    this.element.removeEventListener("direct-upload:error", this._onError)
  }

  // Stimulus action: data-action="click->direct-upload#dismiss" on the
  // overlay's Dismiss button.
  dismiss(event) {
    event?.preventDefault()
    this._showOverlay(false)
    this._setError(null)
    this._showDismiss(false)
    this._submitting = false
    this.uploads.clear()
  }

  _onSubmit() {
    if (this._submitting) return
    this._submitting = true
    this._setError(null)
    this._showDismiss(false)
    this._setLabel("Preparing upload…")
    this._setDetail("")
    if (this.hasProgressTarget) this.progressTarget.style.width = "0%"
    this._showOverlay(true)
  }

  _onStart(event) {
    const { id, file } = event.detail
    this.uploads.set(id, { progress: 0, size: file?.size || 0, name: file?.name || "file" })
    this._renderProgress()
  }

  _onProgress(event) {
    const { id, progress } = event.detail
    const u = this.uploads.get(id)
    if (!u) return
    u.progress = progress
    this._renderProgress()
  }

  _onEnd(event) {
    const { id } = event.detail
    const u = this.uploads.get(id)
    if (u) {
      u.progress = 100
      this._renderProgress()
    }
    if (this._allComplete()) {
      this._setLabel("Saving entry…")
      this._setDetail("Uploads finished. Finishing up…")
    }
  }

  _onError(event) {
    // Cancel Active Storage's default window.alert; keep the overlay
    // visible so the error text inside it is actually rendered.
    event.preventDefault()
    const msg = event.detail?.error || "Upload failed"
    this._setLabel("Upload failed")
    this._setDetail("")
    this._setError(`${msg}. Dismiss to retry.`)
    this._showDismiss(true)
    // overlay stays visible; user clicks Dismiss to close + retry.
  }

  // -- Helpers --

  _allComplete() {
    if (this.uploads.size === 0) return false
    return [...this.uploads.values()].every((u) => u.progress >= 100)
  }

  _aggregatePercent() {
    const total = [...this.uploads.values()].reduce((acc, u) => acc + (u.size || 1), 0)
    if (total === 0) return 0
    const done = [...this.uploads.values()].reduce(
      (acc, u) => acc + (u.size || 1) * (u.progress / 100),
      0
    )
    return Math.round((done / total) * 100)
  }

  _renderProgress() {
    const pct = this._aggregatePercent()
    if (this.hasProgressTarget) this.progressTarget.style.width = `${pct}%`
    const n = this.uploads.size
    const done = [...this.uploads.values()].filter((u) => u.progress >= 100).length
    if (this._allComplete()) {
      this._setLabel("Saving entry…")
    } else {
      this._setLabel(`Uploading ${n} ${n === 1 ? "file" : "files"}… ${pct}%`)
      this._setDetail(`${done} of ${n} complete`)
    }
  }

  _showOverlay(on) {
    if (!this.hasOverlayTarget) return
    this.overlayTarget.classList.toggle("hidden", !on)
  }

  _setLabel(text) {
    if (this.hasLabelTarget) this.labelTarget.textContent = text
  }

  _setDetail(text) {
    if (this.hasDetailTarget) this.detailTarget.textContent = text
  }

  _setError(text) {
    if (!this.hasErrorTarget) return
    this.errorTarget.textContent = text || ""
    this.errorTarget.classList.toggle("hidden", !text)
  }

  _showDismiss(on) {
    if (!this.hasDismissTarget) return
    this.dismissTarget.classList.toggle("hidden", !on)
  }
}
