import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    const details = this.element.querySelector("details")

    if (details) {
      // Open dropdown on hover
      this.element.addEventListener("mouseenter", () => this.open(details))

      // Close dropdown when mouse leaves
      this.element.addEventListener("mouseleave", () => this.close(details))
    }
  }

  open(details) {
    // Close other dropdowns
    document.querySelectorAll("details.nav-menu[open]").forEach(detail => {
      if (detail !== details) {
        detail.removeAttribute("open")
      }
    })
    // Open this dropdown
    details.setAttribute("open", "")
  }

  close(details) {
    details.removeAttribute("open")
  }
}
