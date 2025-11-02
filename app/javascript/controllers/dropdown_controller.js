import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    this.element.addEventListener("mouseleave", () => this.close())

    // Also close other dropdowns when this one opens
    const summary = this.element.querySelector("summary")
    if (summary) {
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
