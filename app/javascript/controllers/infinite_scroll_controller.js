import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { url: String, page: { type: Number, default: 2 } }

  connect() {
    console.log("[InfiniteScroll] Controller connected", {
      element: this.element,
      url: this.urlValue,
      initialPage: this.pageValue
    })

    // Listen for Turbo frame updates to reset page number when articles_list frame reloads
    const articlesFrame = document.getElementById("articles_list")
    if (articlesFrame) {
      articlesFrame.addEventListener("turbo:load", () => {
        const currentFilter = articlesFrame.getAttribute("data-current-filter")
        console.log("[InfiniteScroll] Articles frame reloaded with filter:", currentFilter, "- resetting page to 2")
        this.pageValue = 2
      })
    }

    this.setupObserver()
  }

  setupObserver() {
    console.log("[InfiniteScroll] Setting up intersection observer")

    // Create intersection observer to detect when user scrolls near the bottom
    const observer = new IntersectionObserver(
      (entries) => {
        entries.forEach((entry) => {
          console.log("[InfiniteScroll] Intersection observer fired", {
            isIntersecting: entry.isIntersecting,
            isLoading: this.isLoading,
            boundingClientRect: entry.boundingClientRect
          })

          if (entry.isIntersecting && !this.isLoading) {
            console.log("[InfiniteScroll] Trigger element is visible, loading more articles...")
            this.loadMore()
          }
        })
      },
      { rootMargin: "100px", threshold: 0.1 }
    )

    // Observe this element (the load-more-trigger itself)
    console.log("[InfiniteScroll] Observing element:", this.element.id)
    observer.observe(this.element)
    this.observer = observer
  }

  loadMore() {
    if (this.isLoading) {
      console.log("[InfiniteScroll] Already loading, skipping...")
      return
    }

    this.isLoading = true
    console.log("[InfiniteScroll] Starting loadMore()")

    // Build URL with page parameter and current filters
    const url = new URL(this.urlValue, window.location.origin)
    url.searchParams.set("page", this.pageValue)

    // Get the current filter from the articles_list frame's data attribute
    const articlesFrame = document.getElementById("articles_list")
    const filter = articlesFrame ? articlesFrame.getAttribute("data-current-filter") : "unread"

    // Preserve current filters from the page URL
    const currentUrl = new URL(window.location.href)
    const feedId = currentUrl.searchParams.get("feed_id")
    const category = currentUrl.searchParams.get("category")

    if (filter) url.searchParams.set("filter", filter)
    if (feedId) url.searchParams.set("feed_id", feedId)
    if (category) url.searchParams.set("category", category)

    console.log("[InfiniteScroll] Fetching URL:", url.toString(), {
      page: this.pageValue,
      filter,
      feedId,
      category
    })

    // Fetch and process Turbo Stream response
    fetch(url.toString(), {
      method: "GET",
      headers: {
        "Accept": "text/vnd.turbo-stream.html"
      }
    })
    .then(response => {
      console.log("[InfiniteScroll] Response received", {
        status: response.status,
        statusText: response.statusText,
        contentType: response.headers.get('content-type')
      })
      return response.text()
    })
    .then(html => {
      console.log("[InfiniteScroll] Response HTML length:", html.length)
      console.log("[InfiniteScroll] Response HTML first 500 chars:", html.substring(0, 500))

      // Parse and apply Turbo Stream response
      const parser = new DOMParser()
      const doc = parser.parseFromString(html, 'text/html')

      // Find all turbo-stream elements and process them
      const streams = doc.querySelectorAll('turbo-stream')
      console.log("[InfiniteScroll] Found turbo-stream elements:", streams.length)

      streams.forEach((stream, index) => {
        // Extract the action and target
        const action = stream.getAttribute('action')
        const target = stream.getAttribute('target')
        const template = stream.querySelector('template')

        console.log(`[InfiniteScroll] Processing stream ${index}`, {
          action,
          target,
          hasTemplate: !!template,
          templateContentLength: template ? template.content.childNodes.length : 0
        })

        if (action && target && template) {
          const targetElement = document.getElementById(target)
          console.log(`[InfiniteScroll] Target element found for "${target}":`, !!targetElement)

          if (!targetElement) {
            console.warn(`[InfiniteScroll] Could not find target element with id: ${target}`)
            return
          }

          const content = template.content.cloneNode(true)

          // Apply the appropriate action
          switch (action) {
            case 'append':
              console.log(`[InfiniteScroll] Appending content to ${target}`)
              targetElement.appendChild(content)
              break
            case 'prepend':
              console.log(`[InfiniteScroll] Prepending content to ${target}`)
              targetElement.prepend(content)
              break
            case 'replace':
              console.log(`[InfiniteScroll] Replacing ${target}`)
              targetElement.replaceWith(content)
              break
            case 'remove':
              console.log(`[InfiniteScroll] Removing ${target}`)
              targetElement.remove()
              break
            case 'update':
              console.log(`[InfiniteScroll] Updating ${target}`)
              targetElement.innerHTML = ''
              targetElement.appendChild(content)
              break
            default:
              console.warn(`[InfiniteScroll] Unknown action: ${action}`)
          }
        } else {
          console.warn("[InfiniteScroll] Stream missing required attributes", {
            action,
            target,
            hasTemplate: !!template
          })
        }
      })

      console.log("[InfiniteScroll] All streams processed successfully")
    })
    .catch(error => {
      console.error("[InfiniteScroll] Error loading more articles:", error)
      console.error("[InfiniteScroll] Error details:", error.message, error.stack)
    })
    .finally(() => {
      console.log("[InfiniteScroll] loadMore() complete, incrementing page from", this.pageValue, "to", this.pageValue + 1)
      this.pageValue++
      this.isLoading = false
    })
  }

  disconnect() {
    console.log("[InfiniteScroll] Controller disconnected")
    if (this.observer) {
      this.observer.disconnect()
    }
  }
}
