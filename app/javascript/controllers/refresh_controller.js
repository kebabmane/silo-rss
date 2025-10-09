import { Controller } from "@hotwired/stimulus"
import { visit } from "@hotwired/turbo"

export default class extends Controller {
  reload(event) {
    event.preventDefault()
    visit(window.location.href, { action: "replace" })
  }
}
