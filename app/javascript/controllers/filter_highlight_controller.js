import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    // Listen for turbo:frame-render events to update highlight
    const articlesFrame = document.getElementById("articles_list")
    if (articlesFrame) {
      articlesFrame.addEventListener("turbo:frame-render", () => {
        this.updateHighlight()
      })
    }

    // Also update on initial load
    this.updateHighlight()
  }

  updateHighlight() {
    const articlesFrame = document.getElementById("articles_list")
    const currentFilter = articlesFrame?.getAttribute("data-current-filter") || "unread"

    // Update all filter links
    document.querySelectorAll('[data-filter-link]').forEach((link) => {
      const filter = link.getAttribute('data-filter-value')
      const isActive = filter === currentFilter

      if (isActive) {
        link.classList.remove('text-gray-700', 'dark:text-gray-300', 'hover:bg-gray-100', 'dark:hover:bg-gray-700')
        link.classList.add('bg-blue-50', 'text-blue-700', 'dark:bg-blue-900', 'dark:text-blue-200')
      } else {
        link.classList.remove('bg-blue-50', 'text-blue-700', 'dark:bg-blue-900', 'dark:text-blue-200')
        link.classList.add('text-gray-700', 'dark:text-gray-300', 'hover:bg-gray-100', 'dark:hover:bg-gray-700')
      }
    })
  }
}
