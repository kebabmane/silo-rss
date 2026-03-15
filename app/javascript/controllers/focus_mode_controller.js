import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["layout", "toggle", "label"]

  connect() {
    if (this.hasLayoutTarget) {
      this.focused = this.layoutTarget.classList.contains("focus-mode-active")
    } else {
      this.focused = false
    }
    this.updateToggleAppearance()
  }

  toggle(event) {
    event.preventDefault()
    this.focused = !this.focused
    if (this.hasLayoutTarget) {
      this.layoutTarget.classList.toggle("focus-mode-active", this.focused)
    }
    this.updateToggleAppearance()
  }

  toggleTargetConnected() {
    this.updateToggleAppearance()
  }

  labelTargetConnected() {
    this.updateToggleAppearance()
  }

  updateToggleAppearance() {
    if (this.hasToggleTarget) {
      this.toggleTarget.classList.toggle("is-active", this.focused)
      this.toggleTarget.setAttribute("aria-pressed", String(this.focused))
    }

    if (this.hasLabelTarget) {
      this.labelTarget.textContent = this.focused ? "Exit Focus" : "Focus Mode"
    }
  }
}
