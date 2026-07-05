import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["label"]
  static values = { value: String }

  copy() {
    navigator.clipboard.writeText(this.valueValue).then(() => {
      const original = this.labelTarget.textContent
      this.labelTarget.textContent = "Copied!"
      setTimeout(() => { this.labelTarget.textContent = original }, 2000)
    })
  }
}
