import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { url: String, page: { type: Number, default: 2 }, filter: { type: String, default: "unread" } }

  filterValueChanged(value) {
    this.pageValue = 2
  }

  connect() {
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

    this.isLoading = true

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

      // Parse and apply Turbo Stream response
      const parser = new DOMParser()
      const doc = parser.parseFromString(html, 'text/html')

      // Find all turbo-stream elements and process them
      const streams = doc.querySelectorAll('turbo-stream')

      streams.forEach((stream) => {
        // Extract the action and target
        const action = stream.getAttribute('action')
        const target = stream.getAttribute('target')
        const template = stream.querySelector('template')

        if (action && target && template) {
          const targetElement = document.getElementById(target)

          if (!targetElement) {
            return
          }

          const content = template.content.cloneNode(true)

          // Apply the appropriate action
          switch (action) {
            case 'append':
              targetElement.appendChild(content)
              break
            case 'prepend':
              targetElement.prepend(content)
              break
            case 'replace':
              targetElement.replaceWith(content)
              break
            case 'remove':
              targetElement.remove()
              break
            case 'update':
              targetElement.innerHTML = ''
              targetElement.appendChild(content)
              break
          }
        }
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
