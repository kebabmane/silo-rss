import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="optimistic-action"
export default class extends Controller {
  static targets = ["text", "icon"]
  static values = {
    state: Boolean,
    activeText: String,
    inactiveText: String,
    activeClass: String, // Classes to apply when active (space separated)
    inactiveClass: String, // Classes to apply when inactive
    baseClass: String // Classes that are always present (optional, for cleanup)
  }

  toggle(event) {
    // We don't prevent default here because we want the form to submit via Turbo
    // But we update the UI immediately
    this.stateValue = !this.stateValue
    this.updateUI()
  }

  updateUI() {
    // Update Text
    if (this.hasTextTarget) {
      this.textTarget.textContent = this.stateValue ? this.activeTextValue : this.inactiveTextValue
    } else {
      // Fallback if no target, try to find text node or just replace innerHTML carefully?
      // For now assume target exists or we replace content of the button if it's simple
    }

    // Update Classes on the controller element (the button/form)
    // or a specific target?
    // The current view applies classes to the button itself.
    // So `this.element` is likely the form or the button.
    // Rails button_to generates a form, and the button is inside.
    // So the controller should be on the BUTTON, not the form.
    // If we put it on the button, `this.element` is the button.
    
    if (this.activeClassValue && this.inactiveClassValue) {
      const activeClasses = this.activeClassValue.split(" ")
      const inactiveClasses = this.inactiveClassValue.split(" ")

      if (this.stateValue) {
        this.element.classList.remove(...inactiveClasses)
        this.element.classList.add(...activeClasses)
      } else {
        this.element.classList.remove(...activeClasses)
        this.element.classList.add(...inactiveClasses)
      }
    }
  }
}
