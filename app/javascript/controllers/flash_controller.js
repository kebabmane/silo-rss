import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = {
    timeout: { type: Number, default: 10000 },
    remove: { type: Boolean, default: true }
  }

  connect() {
    this.scheduleHide()
  }

  disconnect() {
    this.clearTimers()
  }

  scheduleHide() {
    this.clearTimers()
    this.hideTimer = setTimeout(() => this.fadeOut(), this.timeoutValue)
  }

  fadeOut() {
    this.element.classList.add("opacity-0", "translate-y-2")
    if (this.removeValue) {
      this.removeTimer = setTimeout(() => this.element.remove(), 500)
    }
  }

  clearTimers() {
    if (this.hideTimer) {
      clearTimeout(this.hideTimer)
      this.hideTimer = null
    }

    if (this.removeTimer) {
      clearTimeout(this.removeTimer)
      this.removeTimer = null
    }
  }
}
