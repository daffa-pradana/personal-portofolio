# Pin npm packages by running ./bin/importmap

pin "application"
pin "@hotwired/turbo-rails", to: "turbo.min.js"
pin "@hotwired/stimulus", to: "stimulus.min.js"
pin "@hotwired/stimulus-loading", to: "stimulus-loading.js"
pin_all_from "app/javascript/controllers", under: "controllers"
pin "trix"
pin "@rails/actiontext", to: "actiontext.esm.js"

# Pinned directly to jsdelivr rather than via `bin/importmap pin` — mermaid's
# dependency tree (cytoscape, dagre, d3, katex) doesn't resolve through
# jspm.io's `generate` API (confirmed: it 404s trying to resolve mermaid's own
# package from npm). The self-contained ESM bundle sidesteps that: its only
# imports are relative "./chunks/..." paths resolved against this same
# jsdelivr URL by the browser, so nothing else needs pinning.
pin "mermaid", to: "https://cdn.jsdelivr.net/npm/mermaid@11.17.2/dist/mermaid.esm.min.mjs"
