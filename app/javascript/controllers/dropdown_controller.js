import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    const details = this.element.querySelector("details")
    const summary = this.element.querySelector("summary")

    if (details && summary) {
      // Close dropdown when mouse leaves the container div (button + menu area)
      this.element.addEventListener("mouseleave", () => this.close(details))

      // Close other dropdowns when this one opens
      summary.addEventListener("click", () => this.closeOtherDropdowns(details))
    }
  }

  close(details) {
    details.removeAttribute("open")
  }

  closeOtherDropdowns(currentDetails) {
    // Close other open dropdowns
    document.querySelectorAll("details.nav-menu[open]").forEach(detail => {
      if (detail !== currentDetails) {
        detail.removeAttribute("open")
      }
    })
  }
}
