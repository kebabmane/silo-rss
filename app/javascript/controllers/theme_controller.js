import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    console.log('Theme controller connected')
    // Load theme from localStorage or default to light
    const savedTheme = localStorage.getItem('theme') || 'light'
    console.log('Loaded theme:', savedTheme)
    this.setTheme(savedTheme)
  }

  toggle() {
    console.log('Toggle clicked')
    const currentTheme = document.documentElement.classList.contains('dark') ? 'dark' : 'light'
    const newTheme = currentTheme === 'dark' ? 'light' : 'dark'
    console.log('Switching from', currentTheme, 'to', newTheme)
    this.setTheme(newTheme)
  }

  setTheme(theme) {
    console.log('Setting theme to:', theme)
    if (theme === 'dark') {
      document.documentElement.classList.add('dark')
    } else {
      document.documentElement.classList.remove('dark')
    }
    localStorage.setItem('theme', theme)
  }
}
