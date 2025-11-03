import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["trigger"]
  static values = { url: String, page: { type: Number, default: 2 } }

  connect() {
    this.observeTarget()
  }

  observeTarget() {
    if (!this.hasTriggerTarget) return

    // Create intersection observer to detect when user scrolls near the bottom
    const observer = new IntersectionObserver(
      (entries) => {
        entries.forEach((entry) => {
          if (entry.isIntersecting && !this.isLoading) {
            this.loadMore()
          }
        })
      },
      { rootMargin: "100px", threshold: 0.1 }
    )

    observer.observe(this.triggerTarget)
    this.observer = observer
  }

  loadMore() {
    if (this.isLoading) return

    this.isLoading = true

    // Build URL with page parameter
    const url = new URL(this.urlValue, window.location.origin)
    url.searchParams.set("page", this.pageValue)

    // Fetch the next page of articles
    const link = document.createElement("a")
    link.href = url.toString()
    link.setAttribute("data-turbo-frame", "articles_list")

    Turbo.visit(link.href, { frame: "articles_list" })

    this.pageValue++
    this.isLoading = false
  }

  disconnect() {
    if (this.observer) {
      this.observer.disconnect()
    }
  }
}
