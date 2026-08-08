# PROGRESS.md — Implementation Tracker

> Living checklist. Claude CLI should update this file at the end of any
> session where progress was made — check off items, add notes on
> decisions/blockers, don't just leave it stale. This is the fast way for
> Daffa to see project status without reading commit history or CLAUDE.md
> in full each time.

**Last updated:** 2026-08-08
**Current focus:** Batch 2 — Articles CMS (Project→Article migration done; next is Action Text + Active Storage)

---

## 🚨 Action Needed First

- [ ] **CI is red on `main` for a reason unrelated to any PR.** `bin/brakeman`
      exits 3 on the `EOLRails` check — "Support for Rails 8.0.4 ends on
      2026-10-07" — which started firing between 2026-08-02 (last green run)
      and 2026-08-08 as the 60-days-to-EOL threshold was crossed. Verified by
      running brakeman against a pristine `main` worktree: same warning, same
      exit 3. This blocks every PR until resolved. Options, for Daffa to pick:
      merge Dependabot PR #7 (rails 8.0.4 → 8.1.3), or add a brakeman ignore
      for `EOLRails`. Deliberately **not** bundled into the migration PR.
- [x] ~~Migrate `Project` → unified `Article` model~~ — done 2026-08-08 on
      branch `feat/project-to-article-migration`. Table renamed in place with
      data preserved; rollback path tested both directions.
- [x] ~~Sync local ↔ remote~~ — verified 2026-08-02, local and `origin/main`
      both at `e712372`, no drift. (Earlier note in this file suggesting
      unpushed commits was incorrect — the confusion came from a stale,
      irregularly-updated `PROJECT_SUMMARY.md` file, not an actual git sync
      issue. That file has since been superseded by this one.)

---

## ✅ Resolved Drift (was: TODO Before Batch 2)

- [x] `app/models/project.rb` + the `projects` table migrated to `Article`.
      `rename_table :projects, :articles`, new columns added, existing rows
      backfilled as `article_type: case_study` / `status: published` with
      `published_at` from `created_at`. No data dropped.
  - [x] `db/seeds/projects.yml` → `db/seeds/articles.yml`, restructured to the
        Article schema. Now matched on `find_by: :slug` (stable natural key)
        rather than `:title`. Idempotency re-verified.
  - [x] `pages_controller.rb` and `_projects.html.erb` now reference `Article`.

### Decisions made during the migration

- **`description` → `subtitle`**, **`live_url` → `button_url`**. `source_code_url`
  was dropped: it has no equivalent in the CLAUDE.md Article schema and was
  `nil` on every existing row.
- **`button_label` is now data, not view logic.** The partial used to hardcode
  `scroll_link ? "Try Here!" : "Product Page"`; the migration backfills exactly
  that rule into the column, so rendered output is unchanged.
- **`default_scope { order(:position) }` was dropped** from the model. It was on
  `Project` and would have silently ordered the future articles index by
  `position` instead of `published_at`. Callers now order explicitly, matching
  the canonical `Article.case_study.published.order(:position).limit(3)`.
- **minitest pinned to `~> 5.25`.** Rails 8.0's `line_filtering.rb` defines
  `run(reporter, options = {})` but minitest 6 calls `run` with three args, so
  *any* `bin/rails test` died with `ArgumentError`. Latent until now because the
  repo had zero tests.

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

- [x] Resolve Project→Article migration (see Resolved Drift above)
- [x] Extend migrated `Article` model with remaining fields (article_type, status,
      slug, subtitle, published_at, reading_time, button_label, button_url)
- [ ] Action Text + Active Storage set up — adds `body` (rich text) and
      `cover_image`. The `reading_time` column exists but stays `nil` until
      `body` does, since it's computed from body word count (~200 wpm)
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

### 2026-08-08
- Confirmed local `main` == `origin/main` at `61be550`; no drift, nothing to pull.
- Confirmed no pending migrations before starting (only `CreateProjects`, applied).
- Deleted-branch check: `backup/local-main-2026-07-05` holds no unmerged work —
  its 4 commits are pre-squash duplicates of what's on `main`, and it is *missing*
  `PROGRESS.md`, `docs/design/`, `CONTRIBUTING.md`, `.githooks/`. Safe to delete.
- Shipped the Project→Article migration on `feat/project-to-article-migration`
  (see Resolved Drift above for the decisions). Verified: migration up, rollback
  down (data restored), up again, seeds idempotent across two runs, 12 model tests
  green, rubocop clean, landing page renders byte-equivalent output.
- **Blocker found:** brakeman `EOLRails` now fails CI on `main` itself. See
  Action Needed First.
- 11 open Dependabot PRs, oldest from 2026-03-12. Three are non-trivial:
  #7 rails 8.0.4→8.1.3, #23 puma 7→8, #22 solid_cable 3→4. Suggested handling
  them in a dedicated pass *after* the migration lands, not alongside it —
  except #7 may get pulled forward to unblock CI.
- `CONTRIBUTING.md` still says "Deployment is currently paused until 25 July 2026",
  which is now past. Needs a one-line cleanup.

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
