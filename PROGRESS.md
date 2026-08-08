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

- [ ] **Nothing blocking.** Next up is Action Text + Active Storage (Batch 2).
- [x] ~~CI red on `main`~~ — fixed by PR #30 (Ruby 3.4.7 + Rails 8.1.3.1),
      merged 2026-08-08. Root cause: brakeman's `EOLRails` rule is
      `(Date.today + 60) >= eol_date`; Rails 8.0's EOL is 2026-10-07, so the
      window opened exactly on 2026-08-08 and brakeman started exiting 3 on
      every branch, `main` included. See the Ruby/Rails upgrade notes below —
      the Rails bump could not land without the Ruby bump.
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
- **minitest was briefly pinned to `~> 5.25`, then unpinned.** Rails 8.0's
  `line_filtering.rb` defines `run(reporter, options = {})` but minitest 6 calls
  `run` with three args, so *any* `bin/rails test` died with `ArgumentError` —
  latent until this PR because the repo had zero tests. Rails 8.1.3.1 rewrote
  that file to dispatch on `Minitest::VERSION` with separate `MT5`/`MT6`
  adapters, so once PR #30 landed the pin became dead code and was removed.

---

## Ruby 3.4.7 + Rails 8.1.3.1 upgrade (PR #30, merged 2026-08-08)

Done to unblock CI, not for its own sake. Two facts worth keeping:

- **The two bumps are inseparable.** Rails 8.1 clears the brakeman EOL check
  (its `RAILS_EOL_DATES` table has no entry above `8.0.99`), but actionview
  8.1.x uses anonymous parameter forwarding inside a block — Ruby 3.4 syntax.
  On Ruby 3.3.0 that is a parse error, so the app dies before booting. Ruby 3.4
  alone leaves `scan_ruby` red; Rails 8.1 alone won't boot. Neither half passes
  CI on its own.
- **`rails`'s gemspec declares `required_ruby_version >= 3.2.0`,** which
  understates what the code needs. Bundler resolves it happily and it only
  fails at parse time — nothing warns you at install.

`Dockerfile`'s `ARG RUBY_VERSION` must move in step with `.ruby-version`: CI
reads `.ruby-version`, but **Railway builds from the Dockerfile**. Bumping only
the former would go green in CI and then fail the deploy on the same
SyntaxError. Verified with a local `docker build` (exit 0) before merging —
`bundle install` under `BUNDLE_DEPLOYMENT=1`, `bootsnap precompile`, and
`assets:precompile` all pass on 3.4.7.

`config.load_defaults` stays at `8.0` deliberately. Moving it to `8.1` is a
separate change with its own behavioral surface — worth doing eventually, but
not as a side effect of a version bump.

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
- **Blocker found and fixed same day:** brakeman `EOLRails` started failing CI
  on `main` itself. Diagnosed, then resolved via PR #30 (Ruby 3.4.7 + Rails
  8.1.3.1) — see the upgrade section above. Dependabot #7 (rails 8.1.3) is
  superseded: it proposed an older patch and could never have passed CI alone,
  since it lacked the Ruby bump. Still open as of end of session; safe to close.
- After #30 merged, `feat/project-to-article-migration` was rebased onto it and
  the minitest pin removed.
- 10 remaining open Dependabot PRs, oldest from 2026-03-12. Two are non-trivial:
  #23 puma 7→8, #22 solid_cable 3→4. Worth a dedicated pass whenever, not
  urgent.
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
