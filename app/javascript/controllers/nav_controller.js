import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["button", "backdrop", "menu"]

  connect() {
    this._onKeydown = this._onKeydown.bind(this)
    document.addEventListener("keydown", this._onKeydown)
  }

  disconnect() {
    document.removeEventListener("keydown", this._onKeydown)
    document.body.style.overflow = ""
  }

  toggle() {
    const isOpen = this.element.classList.toggle("is-open")
    this.buttonTarget.setAttribute("aria-expanded", String(isOpen))
    document.body.style.overflow = isOpen ? "hidden" : ""
  }

  close() {
    if (!this.element.classList.contains("is-open")) return
    this.element.classList.remove("is-open")
    this.buttonTarget.setAttribute("aria-expanded", "false")
    document.body.style.overflow = ""
  }

  _onKeydown(e) {
    if (e.key === "Escape") this.close()
  }
}
