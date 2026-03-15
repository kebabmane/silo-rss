import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    // Load theme from localStorage or use system preference
    const savedTheme = this.getStoredTheme()
    if (savedTheme) {
      this.setTheme(savedTheme)
    } else {
      // Respect system preference when no saved theme exists
      this.applySystemPreference()
    }

    // Listen for system theme changes
    this.mediaQuery = window.matchMedia('(prefers-color-scheme: dark)')
    this.handleSystemChange = this.handleSystemChange.bind(this)
    this.mediaQuery.addEventListener('change', this.handleSystemChange)
  }

  // Safe localStorage access - handles private browsing mode
  getStoredTheme() {
    try {
      return localStorage.getItem('theme')
    } catch {
      return null
    }
  }

  setStoredTheme(theme) {
    try {
      localStorage.setItem('theme', theme)
    } catch {
      // localStorage unavailable (private browsing) - theme will reset on reload
    }
  }

  disconnect() {
    // Clean up event listener
    if (this.mediaQuery) {
      this.mediaQuery.removeEventListener('change', this.handleSystemChange)
    }
  }

  toggle() {
    const currentTheme = document.documentElement.classList.contains('dark') ? 'dark' : 'light'
    const newTheme = currentTheme === 'dark' ? 'light' : 'dark'
    this.setTheme(newTheme)
  }

  setTheme(theme) {
    if (theme === 'dark') {
      document.documentElement.classList.add('dark')
    } else {
      document.documentElement.classList.remove('dark')
    }
    this.setStoredTheme(theme)
  }

  applySystemPreference() {
    const prefersDark = window.matchMedia('(prefers-color-scheme: dark)').matches
    if (prefersDark) {
      document.documentElement.classList.add('dark')
    } else {
      document.documentElement.classList.remove('dark')
    }
  }

  handleSystemChange(e) {
    // Only auto-switch if user hasn't manually set a preference
    const savedTheme = this.getStoredTheme()
    if (!savedTheme) {
      this.applySystemPreference()
    }
  }
}
