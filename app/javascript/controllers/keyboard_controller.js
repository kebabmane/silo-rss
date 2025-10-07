import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    this.currentArticleIndex = 0
    this.articles = []
    document.addEventListener("keydown", this.handleKeyPress.bind(this))
  }

  disconnect() {
    document.removeEventListener("keydown", this.handleKeyPress.bind(this))
  }

  handleKeyPress(event) {
    // Don't trigger shortcuts if user is typing in an input
    if (event.target.tagName === "INPUT" || event.target.tagName === "TEXTAREA") {
      return
    }

    switch(event.key.toLowerCase()) {
      case "j":
        event.preventDefault()
        this.nextArticle()
        break
      case "k":
        event.preventDefault()
        this.previousArticle()
        break
      case "m":
        event.preventDefault()
        this.toggleRead()
        break
      case "s":
        event.preventDefault()
        this.toggleStar()
        break
      case "a":
        event.preventDefault()
        this.archive()
        break
      case "v":
        event.preventDefault()
        this.openOriginal()
        break
      case "?":
        event.preventDefault()
        this.showHelp()
        break
    }
  }

  nextArticle() {
    const articles = document.querySelectorAll('[data-article-id]')
    if (articles.length === 0) return

    this.currentArticleIndex = Math.min(this.currentArticleIndex + 1, articles.length - 1)
    articles[this.currentArticleIndex].click()
  }

  previousArticle() {
    const articles = document.querySelectorAll('[data-article-id]')
    if (articles.length === 0) return

    this.currentArticleIndex = Math.max(this.currentArticleIndex - 1, 0)
    articles[this.currentArticleIndex].click()
  }

  toggleRead() {
    const button = document.querySelector('[data-turbo-method="patch"][formaction*="toggle_read"]')
    if (button) button.click()
  }

  toggleStar() {
    const button = document.querySelector('[data-turbo-method="patch"][formaction*="toggle_starred"]')
    if (button) button.click()
  }

  archive() {
    const button = document.querySelector('[data-turbo-method="patch"][formaction*="toggle_archived"]')
    if (button) button.click()
  }

  openOriginal() {
    const link = document.querySelector('a[target="_blank"]')
    if (link) window.open(link.href, '_blank')
  }

  showHelp() {
    const helpText = `
Keyboard Shortcuts:
j - Next article
k - Previous article
m - Mark as read/unread
s - Star/unstar
a - Archive
v - View original
? - Show this help
    `
    alert(helpText)
  }

  selectArticle(event) {
    const articles = document.querySelectorAll('[data-article-id]')
    const clickedArticle = event.currentTarget
    this.currentArticleIndex = Array.from(articles).indexOf(clickedArticle)
  }
}
