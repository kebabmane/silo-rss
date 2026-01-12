import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["feedButton", "modal"]
  static values = {
    feedsPath: String,
    markCompletedPath: String,
    subscribedFeedUrls: Array
  }

  connect() {
    // Track which feeds have been added this session
    this.addedFeedIds = new Set()
    this.csrfToken = document.querySelector('meta[name="csrf-token"]')?.content
  }

  close(event) {
    event?.preventDefault()
    // Just close the modal without marking onboarding as complete
    // User can see the modal again on next visit
    this.element.remove()
  }

  skip(event) {
    event?.preventDefault()
    // Skip marks onboarding as complete
    this.markOnboardingComplete().finally(() => {
      this.element.remove()
    })
  }

  async addFeed(event) {
    event.preventDefault()
    const button = event.currentTarget
    const feedId = button.dataset.feedId
    const feedUrl = button.dataset.feedUrl
    const category = button.dataset.feedCategory || ""

    // Prevent double-clicks
    if (button.disabled || this.addedFeedIds.has(feedId)) {
      return
    }

    // Show loading state
    button.disabled = true
    const originalText = button.textContent
    button.textContent = "Adding..."
    button.classList.remove("bg-blue-600", "hover:bg-blue-700")
    button.classList.add("bg-gray-400", "cursor-wait")

    try {
      const response = await fetch(this.feedsPathValue, {
        method: "POST",
        headers: {
          "Content-Type": "application/x-www-form-urlencoded",
          "X-CSRF-Token": this.csrfToken,
          "Accept": "application/json"
        },
        body: new URLSearchParams({
          feed_id: feedId,
          category: category
        })
      })

      if (response.ok) {
        // Success - show added state
        this.addedFeedIds.add(feedId)
        button.textContent = "Added"
        button.classList.remove("bg-gray-400", "cursor-wait")
        button.classList.add("bg-green-600", "cursor-default")
      } else {
        // Error - revert button
        button.disabled = false
        button.textContent = originalText
        button.classList.remove("bg-gray-400", "cursor-wait")
        button.classList.add("bg-blue-600", "hover:bg-blue-700")
        console.error("Failed to add feed:", response.status)
      }
    } catch (error) {
      // Network error - revert button
      button.disabled = false
      button.textContent = originalText
      button.classList.remove("bg-gray-400", "cursor-wait")
      button.classList.add("bg-blue-600", "hover:bg-blue-700")
      console.error("Error adding feed:", error)
    }
  }

  showOPML(event) {
    event.preventDefault()

    const opmlForm = document.createElement("form")
    opmlForm.method = "POST"
    opmlForm.action = this.element.dataset.opmlPath
    opmlForm.enctype = "multipart/form-data"
    opmlForm.innerHTML = `
      <input type="file" name="opml_file" accept=".opml,.xml" style="display:none">
      <input type="hidden" name="authenticity_token" value="${this.csrfToken}">
    `
    document.body.appendChild(opmlForm)

    const fileInput = opmlForm.querySelector('input[type="file"]')
    fileInput.addEventListener("change", () => {
      if (fileInput.files.length > 0) {
        // Mark onboarding complete before submitting
        this.markOnboardingComplete().finally(() => {
          opmlForm.submit()
        })
      } else {
        opmlForm.remove()
      }
    }, { once: true })

    fileInput.click()
  }

  async markOnboardingComplete() {
    try {
      await fetch(this.markCompletedPathValue, {
        method: "POST",
        headers: {
          "X-CSRF-Token": this.csrfToken
        }
      })
    } catch (error) {
      console.error("Error marking onboarding complete:", error)
    }
  }

  // Check if a feed URL is already subscribed
  isSubscribed(feedUrl) {
    return this.subscribedFeedUrlsValue.includes(feedUrl)
  }
}
