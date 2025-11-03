import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { url: String, page: { type: Number, default: 2 } }

  connect() {
    this.setupObserver()
  }

  setupObserver() {
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

    // Observe this element (the load-more-trigger itself)
    observer.observe(this.element)
    this.observer = observer
  }

  loadMore() {
    if (this.isLoading) return

    this.isLoading = true

    // Build URL with page parameter and current filters
    const url = new URL(this.urlValue, window.location.origin)
    url.searchParams.set("page", this.pageValue)

    // Preserve current filters from the page URL
    const currentUrl = new URL(window.location.href)
    const filter = currentUrl.searchParams.get("filter")
    const feedId = currentUrl.searchParams.get("feed_id")
    const category = currentUrl.searchParams.get("category")

    if (filter) url.searchParams.set("filter", filter)
    if (feedId) url.searchParams.set("feed_id", feedId)
    if (category) url.searchParams.set("category", category)

    // Use Turbo.visit with frame targeting for turbo_stream response
    fetch(url.toString(), {
      method: "GET",
      headers: {
        "Accept": "text/vnd.turbo-stream.html"
      }
    })
    .then(response => response.text())
    .then(html => {
      // Parse and apply Turbo Stream actions
      const parser = new DOMParser()
      const doc = parser.parseFromString(html, 'text/html')

      // Find all turbo-stream elements and apply them
      const streams = doc.querySelectorAll('turbo-stream')
      streams.forEach(stream => {
        stream.requestSubmit?.() || Turbo.StreamActions[stream.action]?.(stream)
      })
    })
    .catch(error => {
      console.error("Error loading more articles:", error)
    })
    .finally(() => {
      this.pageValue++
      this.isLoading = false
    })
  }

  disconnect() {
    if (this.observer) {
      this.observer.disconnect()
    }
  }
}
