import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["query", "section", "empty"]

  connect() {
    const params = new URLSearchParams(window.location.search)
    const search = params.get("search")
    if (search) {
      this.queryTarget.value = search
    }
    this.filter()
  }

  filter() {
    const q = (this.queryTarget.value || "").trim().toLowerCase()
    let visible = 0

    this.sectionTargets.forEach((el) => {
      const text = (el.textContent || "").toLowerCase()
      const match = !q || text.includes(q)
      el.hidden = !match
      if (match) visible++
    })

    if (this.hasEmptyTarget) {
      this.emptyTarget.hidden = visible > 0
    }
  }
}
