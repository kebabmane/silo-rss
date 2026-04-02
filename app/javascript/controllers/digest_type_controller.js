import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["summaryLength", "description"]

  toggle(event) {
    const isDigest = event.target.value === "digest"

    // Toggle summary length visibility
    if (this.hasSummaryLengthTarget) {
      if (isDigest) {
        this.summaryLengthTarget.classList.add("hidden")
      } else {
        this.summaryLengthTarget.classList.remove("hidden")
      }
    }

    // Update description text
    if (this.hasDescriptionTarget) {
      if (isDigest) {
        this.descriptionTarget.textContent = "Narrative-style digest with trend analysis and cross-story connections."
      } else {
        this.descriptionTarget.textContent = "Concise article-by-article summary."
      }
    }
  }
}
