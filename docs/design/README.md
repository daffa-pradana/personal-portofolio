# Design reference — `docs/design/`

Exported from the Claude design canvas. These files are the **source of truth for
spacing, colour and structure**; the Rails views are the implementation.

```
docs/design/
├── README.md                    ← this file
├── exports/
│   ├── landing_page.html        → app/views/pages/home.html.erb
│   ├── articles_index.html      → app/views/articles/index.html.erb
│   └── article_show.html        → app/views/articles/show.html.erb
└── screenshots/
    ├── landing_page.png
    ├── articles_index.png
    └── article_show.png
```

## How to get them into the repo

1. Download the `docs/design` folder from the chat (or download the whole project
   and keep only that folder).
2. Drop it at the repo root so the paths match the list above — they line up with
   the `## Design Reference Files` section already in your `CLAUDE.md`.
3. Open each export straight from disk (`open docs/design/exports/landing_page.html`)
   to sanity-check it. No build step, no network except one Google Fonts link on
   the article page. The three pages link to each other, so you can click through
   the whole flow.
4. `git add docs/design && git commit -m "Add design reference exports"`.

## What's inside an export

* **Everything is inline-styled on purpose.** Every value you need is on the
  element itself — no cascade to chase while translating to Tailwind.
* **The only `<style>` block holds interaction states** (hover / focus), so the
  behaviour is described in exactly one place. Read it top-to-bottom before
  implementing a card.
* **A comment header** at the top of each file lists the token map
  (hex → Tailwind class), the scale (container, section rhythm, radii, type) and
  the interaction hooks.
* **`data-*` attributes are the contract**, not styling hooks:
  `data-card`, `data-stretch`, `data-btn`, `data-role="arrow"`, `data-role="title"`,
  `data-kind`, `data-filter`, `data-tabs-scope`, `data-col`, `data-prose`.
  Keep those names in the ERB and the CSS block still describes your markup.
* **Placeholders** are the striped grey blocks labelled `PROJECT SHOT`, `COVER`,
  `PORTRAIT`, `HERO IMAGE` — swap in real assets, keep the aspect ratio (16/10 for
  cards, 16/9 for the article hero).
* **Only `articles_index.html` ships JavaScript** (the filter tabs), and only so
  the file works standalone. In Rails, make each tab a link inside
  `turbo_frame_tag "articles"`.

## The card interaction, in one paragraph

The card is a `position: relative` container with a **stretched link** —
`<a data-stretch>` at `absolute inset-0 z-1` — so the whole surface is a real
`<a href>` (⌘-click and middle-click work, no JS). The card's own button sits
**above** it at `relative z-2`, which is why no `stopPropagation` is needed
anywhere. On card hover the card lifts 4px, the title underlines and the
"Read case study →" chip appears; while the pointer is on the button the card
**recedes** (1px, chip at 25%, underline cleared) and the button fills to pure
black with a ring. Tag pills are `pointer-events: none` — static labels.

Tailwind sketch:

```erb
<%# _article_card.html.erb %>
<article class="group relative flex flex-col rounded-xl border border-slate-200 bg-white
                shadow-sm transition duration-200
                hover:-translate-y-1 hover:border-slate-300 hover:shadow-xl
                has-[.card-cta:hover]:translate-y-0 has-[.card-cta:hover]:border-slate-200
                has-[.card-cta:hover]:shadow-md">
  <%= link_to article_path(article), class: "absolute inset-0 z-[1] rounded-xl
        focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-[3px]
        focus-visible:outline-slate-900",
        aria: { label: "Read: #{article.title}" } do %><% end %>
  …cover, chip, title, excerpt, pills…
  <% if article.cta_label.present? %>
    <%= link_to article.cta_href, class: "card-cta relative z-[2] …bg-slate-900 hover:bg-black" do %>
      <%= article.cta_label %>
    <% end %>
  <% end %>
</article>
```

`has-[…]:` needs Tailwind ≥ 3.4. If you'd rather not rely on it, a 6-line
Stimulus controller toggling one class on `mouseenter`/`mouseleave` of the button
does the same thing.

## Decisions I made — confirm or correct

Your screenshot was captured at a ~790px-wide viewport, so I scaled the type up to
a normal desktop scale. If your real classes differ, keep yours and tell me:

| Element | In the export | Tailwind |
|---|---|---|
| Container | 1152px, 24px gutters | `max-w-[1152px] px-6` |
| Header | 64px, sticky, blurred | `h-16 sticky top-0 backdrop-blur` |
| Section rhythm | 88px top/bottom (hero 112/120) | `py-[88px]` |
| Hero `h1` | 60px | `text-6xl` |
| Section `h2` | 32px | `text-3xl` |
| Card title | 16px / 700 | `text-base font-bold` |
| Body copy | 15px / 1.75 | `text-[15px] leading-relaxed` |
| Article prose | Source Serif 4, 20px / 1.78, 680px measure | `prose` w/ custom font |

Also new, flag if unwanted: an "All articles →" link next to *My Latest Projects*,
and a `kind · reading time · date` meta line on the article cards (the home-page
cards don't have it).

## Re-exporting after a design change

Ask me for the change in this project, then say **"re-export the design files"**.
The exports are generated from the canvas files, so don't hand-edit them — edits
would be overwritten and the reference would drift from what you approved.
