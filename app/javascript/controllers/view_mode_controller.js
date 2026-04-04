import { Controller } from "@hotwired/stimulus"

// View mode controller for switching between Normal, Reader views
export default class extends Controller {
  static targets = ["normal", "reader"]
  static values = {
    current: { type: String, default: "normal" }
  }

  connect() {
    // Restore saved preference
    const savedMode = localStorage.getItem("silo-view-mode")
    if (savedMode && savedMode !== this.currentValue) {
      this.switchTo(savedMode)
    } else {
      // Set initial state
      this.updateButtonStyles()
      this.applyLayoutState()
    }

    this.setupKeyboardShortcuts()
  }

  // Switch to a specific view mode
  switchTo(mode) {
    if (!["normal", "reader"].includes(mode)) return

    this.currentValue = mode
    localStorage.setItem("silo-view-mode", mode)

    // Update URL without reload
    const url = new URL(window.location.href)
    if (mode === "normal") {
      url.searchParams.delete("view")
    } else {
      url.searchParams.set("view", mode)
    }
    window.history.pushState({}, "", url)

    // Apply visual feedback
    this.updateButtonStyles()

    // Apply layout state (hide/show sidebar)
    this.applyLayoutState()
  }

  // Toggle between modes
  toggle(event) {
    const mode = event.currentTarget.dataset.mode
    this.switchTo(mode)
  }

  // Apply layout state - hide sidebar in reader mode
  applyLayoutState() {
    const layout = document.querySelector(".dashboard-layout")
    if (layout) {
      if (this.currentValue === "reader") {
        layout.classList.add("focus-mode-active")
      } else {
        layout.classList.remove("focus-mode-active")
      }
    }
  }

  // Cycle through views with 'v' key
  cycleView() {
    const modes = ["normal", "reader"]
    const currentIndex = modes.indexOf(this.currentValue)
    const nextMode = modes[(currentIndex + 1) % modes.length]
    this.switchTo(nextMode)
  }

  // Keyboard shortcuts
  setupKeyboardShortcuts() {
    document.addEventListener("keydown", (e) => {
      // Ignore if typing in input
      if (e.target.matches("input, textarea, [contenteditable]")) return

      switch (e.key) {
        case "v":
          e.preventDefault()
          this.cycleView()
          break
        case "Escape":
          // Reset to normal view
          if (this.currentValue !== "normal") {
            this.switchTo("normal")
          }
          break
      }
    })
  }

  // Update button styles based on active mode
  updateButtonStyles() {
    this.element.setAttribute("data-view-mode", this.currentValue)

    // Update button aria-pressed for accessibility
    this.element.querySelectorAll("[data-mode]").forEach(button => {
      const isActive = button.dataset.mode === this.currentValue
      button.setAttribute("aria-pressed", isActive.toString())
    })
  }
}
