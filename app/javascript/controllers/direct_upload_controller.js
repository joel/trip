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
//   2. On form submit, locks every input + button.
//   3. Listens to direct-upload:start/progress/end/error events that
//      @rails/activestorage dispatches on the form, aggregates per-
//      file progress (size-weighted), and updates the overlay.
//   4. Switches the overlay label from "Uploading…" to "Saving
//      entry…" once all PUTs finish and Rails takes over the submit.
//   5. On error: unlocks the form and surfaces the message so the
//      user can retry without a page reload.
//
// ActiveStorage.start() is idempotent — reconnects are safe.
export default class extends Controller {
  static targets = ["overlay", "label", "progress", "detail", "error"]

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

  _onSubmit() {
    if (this._submitting) return
    this._submitting = true
    this._lockForm()
    this._setError(null)
    this._setLabel("Preparing upload…")
    this._setDetail("")
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
    event.preventDefault()
    const msg = event.detail?.error || "Upload failed"
    this._submitting = false
    this._unlockForm()
    this._showOverlay(false)
    this._setError(`${msg}. Please retry.`)
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

  _lockForm() {
    this.element
      .querySelectorAll("input, textarea, button, select")
      .forEach((el) => { el.disabled = true })
  }

  _unlockForm() {
    this.element
      .querySelectorAll("input, textarea, button, select")
      .forEach((el) => { el.disabled = false })
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
}
