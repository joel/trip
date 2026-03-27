import { Controller } from "@hotwired/stimulus"
import { createConsumer } from "@rails/actioncable"

export default class extends Controller {
  static targets = ["count"]

  connect() {
    this.subscription = createConsumer().subscriptions.create(
      "NotificationsChannel",
      {
        received: (data) => {
          this.updateBadge(data.unread_count)
        }
      }
    )
  }

  disconnect() {
    if (this.subscription) {
      this.subscription.unsubscribe()
    }
  }

  updateBadge(count) {
    if (!this.hasCountTarget) return

    if (count > 0) {
      this.countTarget.textContent = count > 99 ? "99+" : count
      this.countTarget.classList.remove("hidden")
    } else {
      this.countTarget.classList.add("hidden")
    }
  }
}
