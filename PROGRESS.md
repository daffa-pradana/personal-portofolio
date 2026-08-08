# PROGRESS.md — Implementation Tracker

> Living checklist. Claude CLI should update this file at the end of any
> session where progress was made — check off items, add notes on
> decisions/blockers, don't just leave it stale. This is the fast way for
> Daffa to see project status without reading commit history or CLAUDE.md
> in full each time.

**Last updated:** 2026-08-02
**Current focus:** Batch 2 — Articles CMS (Batch 1 is functionally complete)

---

## 🚨 Action Needed First

- [ ] Migrate `Project` → unified `Article` model (see next section). Real
      seed data (`db/seeds/projects.yml`), Stimulus controllers, and a
      Railway deployment already depend on the `Project` model/table, so
      this needs to preserve that rather than a clean-slate rename.
- [x] ~~Sync local ↔ remote~~ — verified 2026-08-02, local and `origin/main`
      both at `e712372`, no drift. (Earlier note in this file suggesting
      unpushed commits was incorrect — the confusion came from a stale,
      irregularly-updated `PROJECT_SUMMARY.md` file, not an actual git sync
      issue. That file has since been superseded by this one.)

---

## ⚠️ Known Drift / TODO Before Batch 2

- [ ] `app/models/project.rb` + `db/migrate/..._create_projects.rb` predate
      the Project→Article unification decision (see CLAUDE.md Database
      Schema section). Plan: write a migration that renames the `projects`
      table to `articles`, adds the new columns (`article_type`, `status`,
      `slug`, `subtitle`, `published_at`, `reading_time`, `button_label`,
      `button_url`), and backfills `article_type: case_study` +
      `status: published` for existing rows — rather than dropping data,
      since there's a live deployment with real seeded projects.
  - [ ] Update `db/seeds/projects.yml` → rename/restructure as part of the
        Article seed convention, or keep as-is if the migration approach
        preserves compatibility — confirm with Daffa before deciding
  - [ ] Update any views/partials referencing `Project` to reference `Article`

---

## Batch 1: Project Scaffolding & Landing Page — ✅ Functionally Complete

- [x] Rails app generated (`personal-portofolio`, Rails 8.0.4, PostgreSQL, Tailwind)
- [x] Repo initialized, pushed to GitHub
- [x] `CLAUDE.md` finalized with unified Article model + design references
- [x] Claude Design exports added (`docs/design/`)
- [x] `database.yml` configured for single `DATABASE_URL` (primary/cache/queue/cable)
- [x] `PagesController#home` + root route
- [x] Landing page partials built: `_navbar`, `_hero`, `_about`, `_projects`, `_contacts`, `_footer`, `_chat` (UI shell only, no backend yet)
- [x] Stimulus: `navbar_controller.js` (mobile menu), `clipboard_controller.js` (copy email)
- [x] `Project` model with PostgreSQL array `tags`, `default_scope order(:position)` — **to be migrated into `Article`, see Known Drift above**
- [x] Seed data: 3 real projects in `db/seeds/projects.yml` via `seed_from_yaml` helper
- [x] Deployed to Railway: `personal-portofolio-production-cdcf.up.railway.app` (region `asia-southeast1`)
- [ ] Partials verified against `docs/design/exports/landing_page.html` (design exports came after this build — worth a pass to confirm alignment)
- [ ] Smooth-scroll navigation (Stimulus) for navbar anchors — confirm if `navbar_controller.js` already covers this
- [ ] Responsive QA (mobile/tablet/desktop breakpoints)

## Batch 2: Articles CMS (Blog + Case Studies, Unified) — Next Up

- [ ] Resolve Project→Article migration (see Known Drift above) — do this first, not alongside new Article features
- [ ] Extend migrated `Article` model with remaining fields not yet present (article_type, status, slug, etc. — see above)
- [ ] Action Text + Active Storage set up
- [ ] `bin/rails generate authentication` run for admin
- [ ] Admin namespace: Article CRUD (type selector, Trix editor)
- [ ] `_card.html.erb` partial with stretched-link pattern (shared: landing
      page "My Latest Projects" + articles index)
- [ ] Public articles index (`/articles`, filter tabs: All/Blog/Case Studies)
- [ ] Public article show page (Medium-style, matches `docs/design/exports/article_show.html`)
- [ ] Turbo Frame filtering on articles index
- [ ] Navbar "Articles" link wired to `/articles`
- [ ] SEO meta tags

## Batch 3: RAG AI Chatbot

- [ ] `KnowledgeEntry` model + migration
- [ ] `ChatService` (Groq API integration)
- [ ] `ChatsController` with rate limiting (10/session, 20/hour/IP)
- [ ] Chat UI with Turbo Streams + Stimulus
- [ ] Suggested question buttons, typing indicator
- [ ] Graceful denial messages (rate limit hit, Groq unavailable)
- [ ] Seed knowledge entries about Daffa

## Batch 4: Polish & Production

- [ ] Admin dashboard: knowledge entries, site settings
- [ ] Image optimization (Active Storage variants)
- [ ] Database indexes + caching
- [ ] GitHub Actions CI pipeline
- [ ] Custom domain + SSL on Railway
- [ ] Final responsive QA across devices

## Batch 5 (Optional/Future)

- [ ] Dark mode
- [ ] Resume/CV page
- [ ] Newsletter subscription
- [ ] i18n (English/Indonesian)
- [ ] RSS feed
- [ ] Sitemap.xml

---

## Reference Info

- **Deployment:** Railway service `personal-portofolio`, region `asia-southeast1`,
  live at `personal-portofolio-production-cdcf.up.railway.app`. Env vars set:
  `RAILS_MASTER_KEY`, `DATABASE_URL`.
- **Real contact info seeded on site:** `daffaarravi@gmail.com`,
  linkedin.com/in/daffaarravi, github.com/daffa-pradana.

## Session Log

Brief notes per work session — what got done, what decisions were made, what's blocked.

### 2026-08-02
- Finalized CLAUDE.md: unified Project → Article model with article_type enum
- Added button_label/button_url for flexible card CTAs (external link or in-page anchor)
- Claude Design exports added to docs/design/
- Found local `PROJECT_SUMMARY.md` (recovered 2026-07-04) describing Batch 1
  progress not visible in remote commits at the time — initially misread as
  unpushed local commits. Daffa confirmed local `git log` matches
  `origin/main` exactly (`e712372`), no sync issue. Root cause was simply
  that `PROJECT_SUMMARY.md` hadn't been kept up to date. Verified its claims
  directly against the repo instead: Project model, seed data
  (`db/seeds/projects.yml`), Stimulus controllers (`navbar_controller.js`,
  `clipboard_controller.js`), and single-`DATABASE_URL` config are all
  confirmed real and present. Railway deployment claim not independently
  verifiable from here — worth a manual spot-check.
- `PROJECT_SUMMARY.md` is now superseded by this file; safe to delete once
  confirmed unneeded.
