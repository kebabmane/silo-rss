import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { url: String, page: { type: Number, default: 2 }, filter: { type: String, default: "unread" } }

  filterValueChanged(value) {
    this.pageValue = 2
  }

  connect() {
    this.lastLoadTime = 0

    // Listen for Turbo frame updates to reset page number when articles_list frame reloads
    const articlesFrame = document.getElementById("articles_list")
    if (articlesFrame) {
      articlesFrame.addEventListener("turbo:frame-render", () => {
        this.pageValue = 2
      })
    }

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
    if (this.isLoading) {
      return
    }

    // Debounce: prevent loading more than once every 300ms
    const now = Date.now()
    if (now - this.lastLoadTime < 300) {
      return
    }

    this.isLoading = true
    this.lastLoadTime = now

    // CRITICAL FIX: Unobserve the trigger element BEFORE fetching
    // This prevents the observer from firing multiple times while content is loading
    if (this.observer) {
      this.observer.unobserve(this.element)
    }

    // Build URL with page parameter and current filters
    const url = new URL(this.urlValue, window.location.origin)
    url.searchParams.set("page", this.pageValue)

    // Get the current filter from the Stimulus data value
    const filter = this.filterValue

    // Preserve current filters from the page URL
    const currentUrl = new URL(window.location.href)
    const feedId = currentUrl.searchParams.get("feed_id")
    const category = currentUrl.searchParams.get("category")

    if (filter) url.searchParams.set("filter", filter)
    if (feedId) url.searchParams.set("feed_id", feedId)
    if (category) url.searchParams.set("category", category)

    // Fetch and process Turbo Stream response
    fetch(url.toString(), {
      method: "GET",
      headers: {
        "Accept": "text/vnd.turbo-stream.html"
      }
    })
    .then(response => response.text())
    .then(html => {

      // Apply Turbo Stream response using the official Turbo API
      Turbo.renderStreamMessage(html)

      // Update articles_list frame data attributes to reflect current state
      const articlesFrame = document.getElementById("articles_list")
      if (articlesFrame) {
        articlesFrame.setAttribute("data-current-filter", this.filterValue)
        // feed_id and category don't change with infinite scroll, but update anyway for consistency
        const currentUrl = new URL(window.location.href)
        const feedId = currentUrl.searchParams.get("feed_id")
        const category = currentUrl.searchParams.get("category")
        if (feedId) articlesFrame.setAttribute("data-current-feed-id", feedId)
        if (category) articlesFrame.setAttribute("data-current-category", category)
      }

      // Dispatch turbo:load to initialize Stimulus controllers on new elements
      document.dispatchEvent(new CustomEvent('turbo:load'))
    })
    .catch(error => {
      console.error("Error loading more articles:", error)
    })
    .finally(() => {
      this.pageValue++
      this.isLoading = false

      // Re-observe the trigger element after loading
      // Check if the element still exists in the DOM (it gets replaced by turbo stream)
      if (this.element && this.element.isConnected && this.observer) {
        this.observer.observe(this.element)
      }
    })
  }

  disconnect() {
    if (this.observer) {
      this.observer.disconnect()
    }
  }
}
