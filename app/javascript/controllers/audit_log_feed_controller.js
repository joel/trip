import { Controller } from "@hotwired/stimulus"
import { createConsumer } from "@rails/actioncable"

// Subscribes to the trip's audit stream and prepends each newly
// broadcast card to the top of the feed without a page reload.
export default class extends Controller {
  static targets = ["list"]
  static values = { tripId: String, showLowSignal: Boolean }

  connect() {
    this.subscription = createConsumer().subscriptions.create(
      { channel: "AuditLogChannel", trip_id: this.tripIdValue },
      {
        received: (data) => {
          if (data.low_signal && !this.showLowSignalValue) return
          if (!this.hasListTarget) return
          this.listTarget.insertAdjacentHTML("afterbegin", data.html)
        }
      }
    )
  }

  disconnect() {
    if (this.subscription) {
      this.subscription.unsubscribe()
    }
  }
}
