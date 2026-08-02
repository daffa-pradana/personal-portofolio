# CLAUDE.md — Daffa Pradana Personal Portfolio Website

> This file provides context for Claude CLI / Claude Code when working on this project.
> Last updated: 2026-08-02 (design reference files added)

## Project Overview

Personal portfolio website for **Daffa Pradana**, a Seasoned Backend Engineer specializing in Ruby on Rails. This project rebuilds an existing Vue-based portfolio into a Rails fullstack app to better showcase Rails expertise.

## Tech Stack

| Layer | Choice | Version |
|-------|--------|---------|
| Framework | Ruby on Rails | 8.0.4 |
| Ruby | Ruby | 3.3.x (latest stable) |
| Frontend | Hotwire (Turbo 8 + Stimulus 3.2) | Ships with Rails 8 |
| JS Bundling | Importmap | Rails default, no Node.js needed |
| CSS | Tailwind CSS | via `tailwindcss-rails` gem |
| Database | PostgreSQL | 16.x |
| Background Jobs | Solid Queue | Rails 8 default, on same PG |
| Caching | Solid Cache | Rails 8 default, on same PG |
| WebSockets | Solid Cable | Rails 8 default, on same PG |
| Auth | Rails 8 built-in authentication | `bin/rails generate authentication` |
| Rich Text | Action Text (Trix editor) | For blog CMS |
| File Upload | Active Storage | For images |
| AI Chat LLM | Groq API (Llama 3.3 70B) | Free tier, OpenAI-compatible |
| Deployment | Railway | Hobby plan ($5/mo) |
| CI/CD | GitHub Actions | Auto-deploy on merge to main |

## Project Structure Conventions

### Seed Data Convention
- **Never hardcode seed data inline in `db/seeds.rb`**
- All seed data lives in YAML files under `db/seeds/<model_name>.yml`
- `seeds.rb` uses the `seed_from_yaml` helper to load and upsert records
- Example: adding a new model's seed data → create `db/seeds/articles.yml`, then add `seed_from_yaml(Article, "articles.yml", find_by: :title)` to `seeds.rb`
- YAML `~` means `nil`; use `find_or_create_by!` so seeds are always idempotent

### Rails Conventions (follow strictly)
- Follow Rails 8 conventions and defaults wherever possible
- Use `params.expect()` (Rails 8 style) instead of `params.require().permit()`
- Use Turbo Frames and Turbo Streams for dynamic UI — avoid writing custom JS unless absolutely necessary
- Use Stimulus controllers only for small UI behaviors (dropdowns, modals, copy-to-clipboard, etc.)
- Use ERB templates (not Haml/Slim)
- Use system tests with Capybara for integration testing
- Use fixtures over factories for test data

### File Organization
```
app/
├── controllers/
│   ├── pages_controller.rb          # Landing page
│   ├── articles_controller.rb       # Public article views (blog + case studies)
│   ├── chats_controller.rb          # AI chatbot endpoint
│   └── admin/
│       ├── base_controller.rb       # Admin auth check
│       ├── articles_controller.rb   # Article CRUD (blog + case studies, one model)
│       └── knowledge_entries_controller.rb  # RAG knowledge CRUD
├── models/
│   ├── user.rb                      # Admin user (Rails 8 auth)
│   ├── article.rb                   # Unified model: blog posts AND project case studies
│   ├── knowledge_entry.rb           # RAG knowledge base
│   └── site_setting.rb              # Dynamic site content (key-value)
├── services/
│   ├── chat_service.rb              # Groq API integration
│   └── knowledge_retriever.rb       # Simple keyword-based retrieval
├── views/
│   ├── layouts/
│   │   ├── application.html.erb     # Main layout
│   │   └── admin.html.erb           # Admin layout
│   ├── pages/
│   │   └── home.html.erb            # Landing page
│   ├── articles/
│   │   ├── index.html.erb           # Article listing (filterable: All/Blog/Case Studies)
│   │   ├── show.html.erb            # Article detail (Medium-like)
│   │   └── _card.html.erb           # Reusable card (stretched-link pattern, used on
│   │                                 # landing page "My Latest Projects" AND articles index)
│   ├── chats/
│   │   └── _message.html.erb        # Chat message partial
│   └── admin/
│       └── ...                      # Admin CRUD views
└── javascript/
    └── controllers/                 # Stimulus controllers
        ├── chat_controller.js       # Chat widget behavior
        ├── navbar_controller.js     # Mobile menu, scroll spy
        └── clipboard_controller.js  # Copy email to clipboard
```

### Naming Conventions
- Models: singular (Article, KnowledgeEntry)
- Controllers: plural (ArticlesController)
- Database tables: plural snake_case (articles, knowledge_entries)
- Stimulus controllers: kebab-case filenames (chat_controller.js → data-controller="chat")
- CSS: Tailwind utility classes only, no custom CSS files unless absolutely necessary
- Views: use partials liberally with `_` prefix

### Routes Structure
```ruby
# config/routes.rb
Rails.application.routes.draw do
  root "pages#home"

  # :slug used as the param (not :id) — see Article model note below
  resources :articles, only: [:index, :show], param: :slug

  # AI Chat endpoint
  post "/chat", to: "chats#create"

  # Admin namespace
  namespace :admin do
    root "dashboard#index"
    resources :articles
    resources :knowledge_entries
    resources :site_settings, only: [:index, :update]
  end

  # Rails 8 auth routes (generated)
  # resource :session
  # resource :password
end
```

## Database Schema

### articles
**Unified model** — a "project case study" IS an Article. There is no separate
Project model. This was a deliberate decision: project cards on the landing
page and blog posts are the same underlying content type, just filtered by
`article_type`. One CRUD, one editor, one slug system for everything Daffa writes.

```
title:string (not null)
subtitle:string
slug:string (unique index, not null)
article_type:integer (default: 0, enum: blog: 0, case_study: 1)
status:integer (default: 0, enum: draft: 0, published: 1)
published_at:datetime
reading_time:integer (minutes)
tags:string[] (PostgreSQL array) — static/non-clickable pills, shown on card + show page
position:integer (nullable — manual curation order; used to pick which 3
                   case_study articles feature in landing page "My Latest
                   Projects" section, NOT necessarily the most recent 3)
button_label:string (nullable) — e.g. "Product Page", "Try Here!"; blank/nil = no button
button_url:string (nullable) — external URL (e.g. "https://happy5.co")
                                OR internal anchor (e.g. "#chat-with-ai") —
                                anchors reuse the exact same Stimulus smooth-scroll
                                behavior as the navbar, no special-casing needed
cover_image → Active Storage attachment
body → Action Text rich text
```

**Card click behavior (landing page + articles index):** the entire card is
clickable and navigates to the article's show page (`/articles/:slug`). This
is implemented with the "stretched link" CSS pattern (title `<a>` gets an
`::after` pseudo-element with `position: absolute; inset: 0;`), NOT nested
`<a>` tags (invalid HTML). The optional `button_label`/`button_url` CTA sits
on top with a higher `z-index` and its own independent `href`, so it
intercepts clicks before they reach the stretched overlay and can navigate
elsewhere (external URL) or smooth-scroll in-page (anchor), independent of
the card's own click-through to the article.

### knowledge_entries
```
category:string (not null) — e.g. "experience", "skills", "education", "personal"
title:string (not null)
content:text (not null)
position:integer (for ordering/priority)
```

### site_settings
```
key:string (unique, not null)
value:text
```

### Solid Stack tables (auto-generated, single PG database)
- solid_queue_* tables
- solid_cache_entries
- solid_cable_messages

## Design Specifications

### Design Philosophy
- Clean, minimal, black-and-white with subtle gray accents
- Rounded corners on cards and buttons
- Professional but approachable
- Mobile-first responsive design

### Landing Page Sections (single page, scroll-based)
1. **Navbar** — Fixed top. Logo "Daffa Pradana" left, nav links right: About, Projects, **Articles**, AI Chat, Contacts. Hamburger on mobile.
   - "About", "Projects", "AI Chat", "Contacts" → smooth-scroll anchors within the landing page (same page)
   - "Articles" → real navigation to `/articles` (full index of all published Articles, both types)
2. **Hero** — Profile photo (rounded), "Hello, I'm Daffa Pradana", "Seasoned Backend Engineer", two CTA buttons (Download CV, Custom).
3. **About Me** — "Get to know" subtitle, "About Me" heading, paragraph about professional background.
4. **Projects** — "What I've been working on" subtitle, "My Latest Projects" heading. Card grid showing
   `Article.case_study.published.order(:position).limit(3)` — see Article schema above for card click
   behavior and optional CTA button. Tags shown as static pills (non-clickable).
5. **AI Chat** — "Know More About Me" subtitle, "Chat with AI" heading, left side: suggested questions, right side: chat interface with message bubbles.
6. **Contacts** — "My Contacts" heading, contact pills (email, LinkedIn, GitHub).
7. **Footer** — Nav links repeated, "Forged with passion in Depok @daffa-pradana".

### Typography
- Headings: Bold, clean sans-serif (Inter or system font stack)
- Body: Regular weight, readable size (16px base)
- Blog articles: Serif font for body text (Medium-like: Georgia or Lora), larger line-height (1.8)

### Responsive Breakpoints
- Mobile: < 640px (single column, hamburger menu)
- Tablet: 640px - 1024px (2 column grids)
- Desktop: > 1024px (full layout as designed)

### Color Palette
- Primary text: #111827 (near black)
- Secondary text: #6B7280 (gray)
- Background: #FFFFFF (white)
- Card borders: #E5E7EB (light gray)
- Accent/buttons: #111827 (black fills) with white text
- Button outline variant: white fill, black border

## AI Chatbot Specifications

### Groq API Integration
```ruby
# Environment variables needed:
# GROQ_API_KEY=gsk_xxxxxxxxxxxx

# API endpoint: https://api.groq.com/openai/v1/chat/completions
# Model: llama-3.3-70b-versatile
# Format: OpenAI-compatible (use ruby-openai gem or net/http)
```

### System Prompt (for Groq)
```
You are an AI assistant on Daffa Pradana's personal portfolio website.
Your ONLY purpose is to answer questions about Daffa — his professional
experience, skills, projects, education, and background.

Rules:
1. Only answer questions related to Daffa Pradana.
2. If asked about anything unrelated to Daffa, politely decline and redirect.
3. Keep answers concise and professional (2-4 sentences max).
4. If you don't have the information, say so honestly.
5. Encourage visitors to contact Daffa directly for detailed inquiries.
6. Never make up information that isn't provided in the context below.

Here is everything you know about Daffa:
{knowledge_entries_content}
```

### Rate Limiting Strategy
- **Per-session:** Max 10 questions per browser session
- **Per-IP:** Max 20 questions per hour (Rails 8 rate_limit)
- **Groq 429 handling:** Catch API rate limit errors gracefully
- **Limit reached message:** "You've reached the question limit for now. For more details about me, feel free to reach out directly via email or LinkedIn below."
- **Groq unavailable message:** "The AI assistant is temporarily unavailable. Please try again later or contact me directly."

### UX Guidelines for Chat
- Show 3-4 suggested quick-ask buttons above the input:
  - "What's Daffa's tech stack?"
  - "Tell me about Daffa's experience"
  - "What projects has Daffa worked on?"
  - "How can I contact Daffa?"
- Small note above chat: "Ask me anything about Daffa — keep it short for quick answers."
- Typing indicator while waiting for Groq response
- Messages styled as bubbles (user right-aligned, AI left-aligned)
- Chat implemented with Turbo Streams for real-time feel

## Articles (CMS) Specifications — Blog + Case Studies, Unified

### Articles Index Page (`/articles`)
- Medium-style card list of ALL published articles (both `blog` and `case_study` types)
- Filter tabs at top: **All / Blog / Case Studies** — implemented as a Turbo Frame,
  no full page reload on filter change
- Each card uses the same `_card.html.erb` partial as the landing page's
  "My Latest Projects" section (see Article schema for click behavior)

### Medium-like Article Show Page Design
- Max content width: 680px (centered)
- Title: Large (32-40px), bold, sans-serif
- Subtitle: Medium (20-24px), gray, regular weight
- Body: Serif font (Georgia/Lora), 18-20px, line-height 1.8
- Code blocks: Monospace, light gray background, rounded
- Images: Full-width within content area, with optional captions
- Reading time shown at top (calculated from word count, ~200 words/min)
- Published date shown at top
- Tags shown as pills below title — static, non-clickable (descriptive only)
- If `article_type == case_study` and `button_label`/`button_url` present,
  render that CTA near the top of the article too (not just on the card)

### Admin Dashboard
- Simple, functional UI (does not need to be fancy)
- Single Article CRUD (covers both blog posts and case studies) with Trix rich text editor
- `article_type` selector (Blog / Case Study) in the form
- `button_label` + `button_url` optional fields in the form (case studies mainly, but
  available for any article)
- Draft/Published toggle
- Image upload for cover images
- Drag-to-reorder (`position` field) — relevant for curating which case studies
  surface in the landing page's "My Latest Projects" section
- Knowledge entry CRUD for RAG content
- Site settings editor (key-value pairs)

## Deployment (Railway)

### Setup
```bash
# Railway CLI
railway login
railway init
railway add --database postgresql

# Environment variables to set in Railway:
RAILS_MASTER_KEY=<from config/master.key>
GROQ_API_KEY=gsk_xxxxxxxxxxxx
RAILS_ENV=production
```

### Database Config
Single PostgreSQL database for everything (app + Solid Stack):
```yaml
# config/database.yml (production)
production:
  primary:
    <<: *default
    url: <%= ENV["DATABASE_URL"] %>
  queue:
    <<: *default
    url: <%= ENV["DATABASE_URL"] %>
    migrations_paths: db/queue_migrate
  cache:
    <<: *default
    url: <%= ENV["DATABASE_URL"] %>
    migrations_paths: db/cache_migrate
  cable:
    <<: *default
    url: <%= ENV["DATABASE_URL"] %>
    migrations_paths: db/cable_migrate
```

### Deploy Command
```bash
git push origin main  # GitHub Actions runs tests → Railway auto-deploys
```

## Design Reference Files

Exported Claude Design output lives in `docs/design/`. Before implementing
any view, view the corresponding exported HTML file as the source of truth
for exact spacing, colors, and structure — translate it into Tailwind
classes + ERB, don't approximate from memory or the prose description alone.
If a design file is missing for a section not yet exported, fall back to the
Design Specifications section above and confirm with Daffa before inventing
new spacing/structure decisions.

- `docs/design/exports/landing_page.html` — hero, about, projects, AI chat, contacts sections
- `docs/design/exports/articles_index.html` — articles listing with All/Blog/Case Studies filter
- `docs/design/exports/article_show.html` — Medium-style article detail page
- `docs/design/screenshots/` — PNG screenshots of the same pages, for quick visual reference

## Development Batches

### Batch 1: Project Scaffolding & Landing Page
1. `rails new personal-portofolio --database=postgresql --css=tailwind --skip-jbuilder` ✅ done
2. Configure Solid Stack on single PG
3. Build PagesController#home
4. Build all landing page sections with Tailwind (responsive)
5. Add smooth scroll navigation with Stimulus (reused by both navbar AND
   optional article `button_url` anchors — build this once, generically)
6. Seed initial Article data (a few `case_study` entries for "My Latest
   Projects" section, about text)
7. Deploy to Railway

### Batch 2: Articles CMS (Blog + Case Studies, unified)
1. Generate unified Article model + migrations (see Database Schema above)
2. Set up Action Text + Active Storage
3. Run `bin/rails generate authentication` for admin
4. Build admin namespace with single Article CRUD (type selector: Blog / Case Study)
5. Build `_card.html.erb` partial with stretched-link pattern (shared between
   landing page "My Latest Projects" and articles index)
6. Build public articles index (`/articles`, filter tabs: All/Blog/Case Studies)
   + show pages (Medium-like typography)
7. Add Turbo Frames for article type filtering
8. Add navbar "Articles" link → `/articles`
9. SEO meta tags

### Batch 3: RAG AI Chatbot
1. Generate KnowledgeEntry model
2. Build ChatService (Groq API integration via net/http or ruby-openai)
3. Build ChatsController with rate limiting
4. Build chat UI with Turbo Streams + Stimulus
5. Add suggested questions, typing indicator
6. Add graceful error handling (rate limits, API failures)
7. Seed knowledge entries about Daffa

### Batch 4: Polish & Production
1. Admin dashboard for projects + knowledge entries
2. Site settings for dynamic content
3. Image optimization (Active Storage variants)
4. Database indexes + caching
5. GitHub Actions CI pipeline
6. Custom domain + SSL on Railway
7. Final responsive QA

## Commands Reference

```bash
# Development
bin/rails server                    # Start dev server
bin/rails console                   # Rails console
bin/rails db:migrate                # Run migrations
bin/rails db:seed                   # Seed data
bin/rails test                      # Run tests
bin/rails test:system               # Run system tests

# Generators
bin/rails generate model Article title:string subtitle:string slug:string \
  article_type:integer status:integer published_at:datetime reading_time:integer \
  tags:string position:integer button_label:string button_url:string
bin/rails generate controller Admin::Articles
bin/rails generate stimulus chat
bin/rails generate authentication

# Tailwind
bin/rails tailwindcss:watch         # Watch for CSS changes (dev)
bin/rails tailwindcss:build         # Build CSS (production)

# Railway
railway login
railway up                          # Deploy
railway logs                        # View logs
railway run bin/rails console       # Remote console
```

## Important Notes

- This project uses **Rails 8.0.4** — always use Rails 8 patterns (params.expect, built-in auth, Solid Stack)
- **No React, No Vue, No Node.js** — everything is Hotwire + Stimulus
- **No Devise** — use Rails 8 built-in authentication generator
- **No Redis** — Solid Stack replaces Redis for queue, cache, and cable
- **No custom webpack/esbuild** — use Importmap
- **Single PostgreSQL** — app data + Solid Stack all in one database
- **Groq API** — OpenAI-compatible format, model: `llama-3.3-70b-versatile`
- **No separate Project model** — project case studies are `Article` records with
  `article_type: case_study`. Do not create a `Project` model/controller/table.
- **Card stretched-link pattern** — required for project/article cards where the
  whole card AND an independent optional button must both be clickable. See
  Article schema section for the CSS approach.
- When the Groq rate limit or session question limit is hit, respond with a denial message and redirect to contacts — never show raw errors to visitors
- Keep the design minimal, clean, black-and-white per the Figma reference
