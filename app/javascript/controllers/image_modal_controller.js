import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["overlay", "fullImage"]

  connect() {
    this.boundHandleKeydown = this.handleKeydown.bind(this)
  }

  open(event) {
    const src = event.currentTarget.dataset.imageSrc
    if (!src || !this.hasOverlayTarget || !this.hasFullImageTarget) return
    this.fullImageTarget.src = src
    this.overlayTarget.hidden = false
    this.overlayTarget.setAttribute("aria-hidden", "false")
    document.body.style.overflow = "hidden"
    document.addEventListener("keydown", this.boundHandleKeydown)
    this.fullImageTarget.focus()
  }

  close() {
    if (!this.hasOverlayTarget) return
    this.overlayTarget.hidden = true
    this.overlayTarget.setAttribute("aria-hidden", "true")
    document.body.style.overflow = ""
    document.removeEventListener("keydown", this.boundHandleKeydown)
  }

  handleKeydown(event) {
    if (event.key === "Escape") this.close()
  }

  disconnect() {
    document.body.style.overflow = ""
    document.removeEventListener("keydown", this.boundHandleKeydown)
  }
}
