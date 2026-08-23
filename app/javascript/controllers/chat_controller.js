import { Controller } from "@hotwired/stimulus"

// Small UI-only behaviours around the chat form. The actual message exchange
// is a plain Turbo form POST answered with Turbo Streams — this controller
// never renders a message itself.
export default class extends Controller {
  static targets = ["form", "input", "typing", "scroller"]

  connect() {
    // Turbo Streams append into #chat-messages, which this controller doesn't
    // own, so watch the scroller for new nodes and keep the view pinned to
    // the newest message.
    this.observer = new MutationObserver(() => this.scrollToBottom())
    this.observer.observe(this.scrollerTarget, { childList: true, subtree: true })
  }

  disconnect() {
    this.observer?.disconnect()
  }

  // Clicking a suggested question fills the input and submits immediately.
  suggest(event) {
    this.inputTarget.value = event.params.question
    this.formTarget.requestSubmit()
  }

  showTyping() {
    this.typingTarget.classList.remove("hidden")
    this.scrollToBottom()
  }

  hideTyping() {
    this.typingTarget.classList.add("hidden")
    // The server echoes the question back as a bubble, so the input has done
    // its job by now and clearing it avoids a duplicate resubmit.
    this.inputTarget.value = ""
  }

  scrollToBottom() {
    this.scrollerTarget.scrollTop = this.scrollerTarget.scrollHeight
  }
}
