import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    // Load theme from localStorage or default to light
    const savedTheme = localStorage.getItem('theme') || 'light'
    this.setTheme(savedTheme)
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
    localStorage.setItem('theme', theme)
  }
}
