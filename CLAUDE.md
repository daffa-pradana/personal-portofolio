# CLAUDE.md — Daffa Pradana Personal Portfolio Website

> This file provides context for Claude CLI / Claude Code when working on this project.
> Last updated: 2026-03-10

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
│   ├── articles_controller.rb       # Public blog views
│   ├── chats_controller.rb          # AI chatbot endpoint
│   └── admin/
│       ├── base_controller.rb       # Admin auth check
│       ├── articles_controller.rb   # Blog CRUD
│       ├── projects_controller.rb   # Projects CRUD
│       └── knowledge_entries_controller.rb  # RAG knowledge CRUD
├── models/
│   ├── user.rb                      # Admin user (Rails 8 auth)
│   ├── article.rb                   # Blog posts
│   ├── project.rb                   # Portfolio projects
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
│   │   ├── index.html.erb           # Blog listing
│   │   └── show.html.erb            # Article detail (Medium-like)
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
- Models: singular (Article, Project, KnowledgeEntry)
- Controllers: plural (ArticlesController, ProjectsController)
- Database tables: plural snake_case (articles, projects, knowledge_entries)
- Stimulus controllers: kebab-case filenames (chat_controller.js → data-controller="chat")
- CSS: Tailwind utility classes only, no custom CSS files unless absolutely necessary
- Views: use partials liberally with `_` prefix

### Routes Structure
```ruby
# config/routes.rb
Rails.application.routes.draw do
  root "pages#home"

  resources :articles, only: [:index, :show]

  # AI Chat endpoint
  post "/chat", to: "chats#create"

  # Admin namespace
  namespace :admin do
    root "dashboard#index"
    resources :articles
    resources :projects
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
```
title:string (not null)
subtitle:string
slug:string (unique index, not null)
status:integer (default: 0, enum: draft/published)
published_at:datetime
reading_time:integer (minutes)
tags:string[] (PostgreSQL array)
cover_image → Active Storage attachment
body → Action Text rich text
```

### projects
```
title:string (not null)
description:text
tags:string[] (PostgreSQL array)
source_code_url:string
live_url:string
position:integer (for ordering)
image → Active Storage attachment
```

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
1. **Navbar** — Fixed top. Logo "Daffa Pradana" left, nav links right (About, Projects, AI Chat, Contacts). Hamburger on mobile.
2. **Hero** — Profile photo (rounded), "Hello, I'm Daffa Pradana", "Seasoned Backend Engineer", two CTA buttons (Download CV, Custom).
3. **About Me** — "Get to know" subtitle, "About Me" heading, paragraph about professional background.
4. **Projects** — "What I've been working on" subtitle, "My Latest Projects" heading, card grid (image, title, tag pills).
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

## Blog (CMS) Specifications

### Medium-like Article Design
- Max content width: 680px (centered)
- Title: Large (32-40px), bold, sans-serif
- Subtitle: Medium (20-24px), gray, regular weight
- Body: Serif font (Georgia/Lora), 18-20px, line-height 1.8
- Code blocks: Monospace, light gray background, rounded
- Images: Full-width within content area, with optional captions
- Reading time shown at top (calculated from word count, ~200 words/min)
- Published date shown at top
- Tags shown as pills below title

### Admin Dashboard
- Simple, functional UI (does not need to be fancy)
- Article CRUD with Trix rich text editor
- Draft/Published toggle
- Image upload for cover images
- Project CRUD with drag-to-reorder (position field)
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

## Development Batches

### Batch 1: Project Scaffolding & Landing Page
1. `rails new daffa-portfolio --database=postgresql --css=tailwind`
2. Configure Solid Stack on single PG
3. Build PagesController#home
4. Build all landing page sections with Tailwind (responsive)
5. Add smooth scroll navigation with Stimulus
6. Seed initial data (projects, about text)
7. Deploy to Railway

### Batch 2: Blog CMS
1. Generate Article model + migrations
2. Set up Action Text + Active Storage
3. Run `bin/rails generate authentication` for admin
4. Build admin namespace with article CRUD
5. Build public article index + show pages (Medium-like typography)
6. Add Turbo Frames for article filtering
7. SEO meta tags

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
bin/rails generate model Article title:string slug:string status:integer
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
- When the Groq rate limit or session question limit is hit, respond with a denial message and redirect to contacts — never show raw errors to visitors
- Keep the design minimal, clean, black-and-white per the Figma reference
