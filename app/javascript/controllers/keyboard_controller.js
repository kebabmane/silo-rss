import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    this.currentArticleIndex = 0
    this.articles = []
    this.boundHandleKeyPress = this.handleKeyPress.bind(this)
    document.addEventListener("keydown", this.boundHandleKeyPress)
  }

  disconnect() {
    document.removeEventListener("keydown", this.boundHandleKeyPress)
  }

  handleKeyPress(event) {
    // Don't trigger shortcuts if user is typing in an input or editable element
    const target = event.target
    const tagName = target.tagName
    if (
      tagName === "INPUT" ||
      tagName === "TEXTAREA" ||
      tagName === "SELECT" ||
      target.isContentEditable ||
      target.closest('[contenteditable="true"]')
    ) {
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
    // button_to creates a form with action, find the form and click its button
    const form = document.querySelector('form[action*="toggle_read"]')
    const button = form?.querySelector('button')
    if (button) button.click()
  }

  toggleStar() {
    const form = document.querySelector('form[action*="toggle_starred"]')
    const button = form?.querySelector('button')
    if (button) button.click()
  }

  archive() {
    const form = document.querySelector('form[action*="toggle_archived"]')
    const button = form?.querySelector('button')
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
