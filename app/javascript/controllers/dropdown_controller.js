import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    const summary = this.element.querySelector("summary")
    const details = this.element.querySelector("details")

    // Prevent click from toggling the details element
    if (summary) {
      summary.addEventListener("click", (e) => e.preventDefault())
    }

    // Open dropdown on hover
    this.element.addEventListener("mouseenter", () => this.open())

    // Close dropdown when mouse leaves the entire dropdown container
    this.element.addEventListener("mouseleave", () => {
      // Use a small delay to allow moving to dropdown content
      setTimeout(() => {
        if (!this.element.matches(":hover")) {
          this.close()
        }
      }, 100)
    })

    // Keep dropdown open when hovering over the menu content
    if (details) {
      details.addEventListener("mouseenter", () => this.open())
      details.addEventListener("mouseleave", () => {
        setTimeout(() => {
          if (!this.element.matches(":hover")) {
            this.close()
          }
        }, 100)
      })
    }
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
