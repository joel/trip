import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["body", "label"]
  static values = { expanded: Boolean }

  toggle() {
    this.expandedValue = !this.expandedValue
    this.bodyTarget.hidden = !this.expandedValue
    this.labelTarget.textContent = this.expandedValue
      ? "Collapse"
      : "Read more"
  }
}
