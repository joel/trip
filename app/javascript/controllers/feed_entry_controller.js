import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["body", "label", "preview", "chevron"]
  static values = { expanded: Boolean }

  toggle() {
    this.expandedValue = !this.expandedValue
    this.bodyTarget.hidden = !this.expandedValue
    this.labelTarget.textContent = this.expandedValue
      ? "Collapse"
      : "Read more"

    if (this.hasPreviewTarget) {
      this.previewTarget.hidden = this.expandedValue
    }

    if (this.hasChevronTarget) {
      this.chevronTarget.style.transform = this.expandedValue
        ? "rotate(180deg)"
        : ""
    }
  }
}
