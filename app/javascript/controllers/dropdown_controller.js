import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    const summary = this.element.querySelector("summary")
    if (summary) {
      // Close dropdown when mouse leaves the summary button
      summary.addEventListener("mouseleave", () => this.close())

      // Close other dropdowns when this one opens
      summary.addEventListener("click", () => this.closeOtherDropdowns())
    }
  }

  close() {
    this.element.removeAttribute("open")
  }

  closeOtherDropdowns() {
    // Close other open dropdowns
    document.querySelectorAll("details.nav-menu[open]").forEach(detail => {
      if (detail !== this.element) {
        detail.removeAttribute("open")
      }
    })
  }
}
