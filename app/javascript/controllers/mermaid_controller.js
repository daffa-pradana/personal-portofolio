import { Controller } from "@hotwired/stimulus"

// Renders any `pre.mermaid` diagrams inside this element. Scoped to the
// article body (rather than run globally) since only case-study articles
// currently embed diagrams. Article bodies are static Action Text HTML with
// no client-side re-renders, so a plain `connect()` run is enough — no
// MutationObserver needed.
export default class extends Controller {
  async connect() {
    const nodes = this.element.querySelectorAll("pre.mermaid")
    if (nodes.length === 0) return

    const { default: mermaid } = await import("mermaid")
    // "loose" (not the "strict" default) so `<br/>` inside node labels — used
    // throughout these diagrams for multi-line labels — renders as an actual
    // line break instead of literal escaped text. Safe here: article bodies
    // are authored by Daffa through the admin CMS, never visitor input.
    mermaid.initialize({ startOnLoad: false, theme: "neutral", securityLevel: "loose" })
    await mermaid.run({ nodes })
  }
}
