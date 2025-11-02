import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    // Open dropdown on hover
    this.element.addEventListener("mouseenter", () => this.open())

    // Close dropdown when mouse leaves
    this.element.addEventListener("mouseleave", () => this.close())
  }

  open() {
    const details = this.element.querySelector("details")
    if (!details) return

    // Close other open dropdowns
    document.querySelectorAll('[data-controller="dropdown"]').forEach(dropdown => {
      if (dropdown !== this.element) {
        const otherDetails = dropdown.querySelector("details")
        if (otherDetails && otherDetails.hasAttribute("open")) {
          otherDetails.removeAttribute("open")
        }
      }
    })

    // Open this dropdown using the native details open attribute
    details.setAttribute("open", "open")
  }

  close() {
    const details = this.element.querySelector("details")
    if (details) {
      details.removeAttribute("open")
    }
  }
}
