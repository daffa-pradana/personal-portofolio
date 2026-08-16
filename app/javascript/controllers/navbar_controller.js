import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["menu", "hamburger", "close"]

  toggleMenu() {
    const isOpen = !this.menuTarget.classList.contains("hidden")
    this.menuTarget.classList.toggle("hidden", isOpen)
    this.hamburgerTarget.classList.toggle("hidden", !isOpen)
    this.closeTarget.classList.toggle("hidden", isOpen)
  }

  closeMenu() {
    this.menuTarget.classList.add("hidden")
    this.hamburgerTarget.classList.remove("hidden")
    this.closeTarget.classList.add("hidden")
  }
}
