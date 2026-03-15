import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { url: String, delay: { type: Number, default: 2000 } }

  connect() {
    if (!this.urlValue) return
    this.timer = setTimeout(() => this.markRead(), this.delayValue)
  }

  disconnect() {
    clearTimeout(this.timer)
  }

  markRead() {
    fetch(this.urlValue, {
      method: 'PATCH',
      headers: {
        'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]').content,
        'Accept': 'text/vnd.turbo-stream.html'
      }
    })
  }
}
