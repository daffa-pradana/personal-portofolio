# PROGRESS.md — Implementation Tracker

> Living checklist. Claude CLI should update this file at the end of any
> session where progress was made — check off items, add notes on
> decisions/blockers, don't just leave it stale. This is the fast way for
> Daffa to see project status without reading commit history or CLAUDE.md
> in full each time.

**Last updated:** 2026-08-16
**Current focus:** Batch 2 is complete (pending PR merge). Next up is Batch 3
— the RAG AI chatbot (KnowledgeEntry model, ChatService/Groq, ChatsController).

---

## 🚨 Action Needed First

- [ ] **Nothing blocking.** Next up is Batch 3: `KnowledgeEntry` model,
      `ChatService` (Groq API integration), `ChatsController` with rate
      limiting, chat UI via Turbo Streams.
- [ ] Create a local admin user before using the CMS:
      `ADMIN_EMAIL=... ADMIN_PASSWORD=... bin/rails db:seed`
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
- [x] Smooth-scroll navigation — **done in CSS, not Stimulus.** The layout's
      `<html class="scroll-smooth">` covers navbar anchors *and* article
      `button_url` anchors automatically, which is the "build it once,
      generically" intent from CLAUDE.md Batch 1 step 5 with no JS at all.
      `navbar_controller.js` only handles the mobile menu toggle.
  - [ ] Minor: the navbar is `fixed` at `h-16` (64px) and no section has
        `scroll-mt-16`. Section `py-24` padding absorbs it, so headings land
        ~32px below the navbar instead of the designed 96px. Nothing is hidden.
- [x] "Download CV" button no longer 404s — it was hardcoded to
      `/daffa-pradana-cv.pdf`, a file that has never existed in `public/`. Now
      driven by `SiteSetting[:cv_url]` and rendered only when that's set.
- [ ] Responsive QA (mobile/tablet/desktop breakpoints)

## Batch 2: Articles CMS (Blog + Case Studies, Unified) — Next Up

- [x] Resolve Project→Article migration (see Resolved Drift above)
- [x] Extend migrated `Article` model with remaining fields (article_type, status,
      slug, subtitle, published_at, reading_time, button_label, button_url)
- [x] Action Text + Active Storage set up — `has_rich_text :body`,
      `has_one_attached :cover_image`, and `reading_time` now computed on save
      from body word count at 200 wpm (`Article::WORDS_PER_MINUTE`), rounded up,
      `nil` when there's no body. Landing page cards render `cover_image` when
      attached and fall back to the placeholder SVG otherwise.
  - [ ] **Production Active Storage service is `:local` disk**
        (`config/environments/production.rb:25`). Railway's container filesystem
        is ephemeral, so uploads would vanish on every redeploy. Needs an S3/R2
        service before the admin CRUD is used in production — not urgent while
        deployment is paused, but a real trap to remember.
  - [ ] Seed articles have no `body` yet, so their `reading_time` is `nil`.
        Deliberate: writing filler article content isn't Claude's call.
        Add real bodies via the admin editor once it exists.
- [x] `bin/rails generate authentication` run for admin — `User` + `Session`
      models, `Authentication` concern, sessions/passwords controllers and views.
      Auth views retinted from the generator's blue to the black-and-white
      palette in CLAUDE.md.
  - [x] **`PagesController` opts out via `allow_unauthenticated_access`.** The
        generator adds `before_action :require_authentication` to
        `ApplicationController`, which locks *every* controller by default —
        the landing page returned 403 until the opt-out was added. Every future
        visitor-facing controller (articles index, article show, chat) needs the
        same opt-out. `test/controllers/pages_controller_test.rb` guards this.
  - [x] Admin user seeded from `ADMIN_EMAIL` / `ADMIN_PASSWORD` env vars — see
        `db/seeds.rb`. Deliberately not in `db/seeds/*.yml`, since a password
        can't be committed. Seeding is a no-op when the vars are absent.
  - [ ] No admin user exists in the local dev DB yet. Create one with:
        `ADMIN_EMAIL=... ADMIN_PASSWORD=... bin/rails db:seed`
  - [ ] `config/environments/production.rb:61` still has the generator's
        placeholder `default_url_options = { host: "example.com" }`. Password
        reset links would point at the wrong host. Parked with deployment.
- [x] Admin namespace: Article CRUD (type selector, Trix editor) — PR #36.
      `Admin::BaseController` adds no opt-out, so it inherits
      `require_authentication` from `ApplicationController` — that's the
      whole auth gate. Routes use `resources :articles, param: :slug` to
      match `Article#to_param` (global slug lookup); `tags` is a single
      comma-separated text field, split into the Postgres array column
      server-side. Drag-to-reorder for `position` deliberately deferred —
      a plain number field covers the curation need for now.
- [x] `_card.html.erb` partial with stretched-link pattern — shared by the
      landing page's "My Latest Projects" section (`show_meta: false`, no
      type/date/reading-time line — the design export deliberately omits it
      there) and the articles index (`show_meta: true`, the default).
- [x] Public articles index (`/articles`) — filter tabs All/Blog/Case Studies.
- [x] Public article show page (Medium-style) — Source Serif 4 20px/1.78 on
      a 680px measure, scoped via `.article-body .trix-content` in
      `application.css` so the admin's Trix editor keeps its own sizing.
- [x] Turbo Frame filtering on articles index — one `turbo_frame_tag
      "articles"` wraps both the tabs and the grid; tab links are plain
      `articles_path(kind: ...)` GETs, no controller branching needed beyond
      filtering `@articles` by `params[:kind]`.
- [x] Navbar "Articles" link wired to `/articles` — `_navbar.html.erb` and
      `_footer.html.erb` now use `root_path(anchor: "about")` etc. instead of
      bare `"#about"`, so the same partials work unchanged from `/articles`
      and `/articles/:slug` (real navigation back to `/`, then scroll) as
      well as from the landing page itself (plain in-page scroll).
- [x] SEO meta tags — `<title>`/description/Open Graph tags in
      `application.html.erb`, set per-page via `content_for`.

**Batch 2 is now functionally complete**, pending PR review/merge.

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

### 2026-08-22 — public articles pages (Batch 2 complete)

- Built the entire public-facing remainder of Batch 2 in one PR:
  `_card.html.erb`, the `/articles` index with Turbo Frame filter tabs, the
  article show page, navbar/footer wiring, and SEO meta tags.
- Refactored `_projects.html.erb` (landing page) to render the new shared
  `articles/_card` partial instead of its own inline markup — the design
  export's own README explicitly calls out that the two cards should share
  one partial. Caught a real discrepancy while translating: the landing
  page's cards deliberately omit the "type · reading time · date" meta line
  that the articles-index cards have (`docs/design/README.md`'s own
  "Decisions I made" section flags this), so the partial takes a
  `show_meta:` local rather than always rendering it.
- `_navbar.html.erb`/`_footer.html.erb` switched from bare `"#about"` anchors
  to `root_path(anchor: "about")` etc. — works identically on the landing
  page and lets the exact same partials be reused on `/articles` and
  `/articles/:slug` without any "am I on the home page" branching.
- Turbo Frame filtering needed zero JS and zero extra controller logic:
  wrapping both the tabs and the grid in one `turbo_frame_tag "articles"`
  is enough — Turbo automatically extracts the matching frame from
  whichever full-page response comes back, so `ArticlesController#index`
  only had to filter `@articles` by `params[:kind]`.
- Article prose typography (Source Serif 4, 20px/1.78, 680px measure) is
  scoped via a `.article-body .trix-content` compound selector in
  `application.css` — deliberately not touching plain `.trix-content`,
  which would also restyle the Trix editor while writing in the admin CMS.
  Higher specificity than actiontext.css's single-class rule wins regardless
  of stylesheet load order, so this doesn't depend on file ordering.
- Brakeman caught a real (if low-severity) issue during verification: the
  byline's `"date · reading time"` line used `&middot;` + `.html_safe` on a
  join of model-derived strings — flagged as "unescaped model attribute."
  Fixed by using a literal `·` character and dropping `.html_safe` entirely,
  in both this page and the card partial.
- 62 -> 73 tests, all green. 0 rubocop offenses, 0 brakeman warnings.
- **Batch 2 is functionally complete** as of this PR (pending review/merge).
  Batch 3 (RAG AI chatbot) is next.

### 2026-08-16 (later — admin namespace + Article CRUD)

- Built `Admin::BaseController`, `Admin::DashboardController`, and
  `Admin::ArticlesController` (full CRUD) — PR #36.
- Verified beyond the test suite: booted the app in development, created a
  throwaway admin user, and drove create → edit → update → destroy over
  real HTTP (curl with a real cookie jar and CSRF tokens, not just the test
  DB) before removing the probe user. Confirmed tags round-trip through the
  comma-separated text field into the Postgres array column, and that the
  slug-based route lookup (`param: :slug`) actually resolves — this was the
  one part of the design that couldn't be trusted from the test suite alone,
  since `Article#to_param` returning the slug globally is easy to get
  subtly wrong (e.g. `Article.find(params[:id])` would have looked right in
  a diff but 404'd for real, since the URL segment is never a numeric id).
- 51 -> 62 tests, all green. 0 rubocop offenses, 0 brakeman warnings.

### 2026-08-16 — Dependabot housekeeping sweep

- **Found `main` itself was newly broken** before touching any Dependabot PR:
  Brakeman 8.0.6 released today, `bin/brakeman` hardcodes `--ensure-latest`
  (Rails 8 default), so `scan_ruby` started failing on every branch including
  `main`. Same failure shape as PR #30's `EOLRails` issue, different trigger
  (plain version staleness, not the EOL-date check). Fixed via PR #34
  (brakeman 8.0.5 → 8.0.6, 0 warnings, rubocop clean, 51 tests green) —
  merged first since nothing else could pass CI without it.
- Closed **#7** (`rails 8.0.4 → 8.1.3`) as superseded — PR #30 already shipped
  a newer patch (8.1.3.1) back in August.
- Merged 9 of the remaining 10 open Dependabot PRs after syncing each against
  the fixed `main`: **#1** upload-artifact, **#2** actions/checkout, **#4**
  kamal, **#5** solid_queue, **#12** propshaft, **#18** selenium-webdriver,
  **#20** thruster, **#22** solid_cable (3→4), **#23** puma (7→8), **#24**
  bootsnap.
  - **#22 and #23** are major-version bumps — checked their release notes
    before merging rather than trusting CI alone: solid_cable 4.0's only
    breaking change is dropping Ruby 3.1/3.2 support (we're on 3.4.7, so
    n/a); no config/schema changes. Puma 7→8 passed the full suite with no
    behavior changes surfaced.
  - **#12, #22, #24 had real `Gemfile.lock` conflicts** against `main`
    (textual clashes from the brakeman/ruby/rails bumps earlier this month).
    Dependabot's own rebase attempt didn't fully resolve them. Fixed by hand:
    reset each branch's lockfile to `main`'s, then `bundle update <gem>
    --conservative` so only the target gem (and its direct deps) moved —
    verified via `git diff` that no unrelated gem shifted before committing.
  - **#2 (actions/checkout) needed a plain `git merge` + `git push` over SSH**
    instead of the GitHub API's update-branch endpoint — `gh`'s OAuth token
    lacks the `workflow` scope required to update a PR that touches
    `.github/workflows/*` via the API. Not an issue for direct git pushes.
  - Branch protection (`strict` mode) meant every merge shifted `main` and
    invalidated the "behind" state of whichever PRs hadn't merged yet —
    each one needed a fresh sync immediately before its own merge, not once
    up front.
- Fixed a stale line in `CONTRIBUTING.md`: "paused until 25 July 2026" → the
  date passed and the deployment pause is indefinite (part of PR #34).
- **End state:** 0 open PRs, `main` green (0 Brakeman warnings, 0 rubocop
  offenses, 51/51 tests), fully verified locally after the final merge, not
  just trusted from individual PR CI runs.

### 2026-08-08 (later still — SiteSetting + dynamic CV button)
- **The résumé PDF is deliberately NOT in this repo, and must never be.** It's a
  PII document and the repo is public; git history is permanent, so committing
  it once is effectively irreversible. Daffa raised the concern himself and it
  was the right call. The CV is hosted externally and referenced by URL.
- `SiteSetting` model with `SiteSetting[:key]` / `SiteSetting[:key] = value`.
  Blank and missing collapse to `nil`, since callers only ask "is this
  configured?".
- `seed_from_yaml` gained `update_existing: false`, used for site settings:
  seeding creates missing keys but never overwrites a value set through the
  admin UI. Verified by seeding, setting a value, and re-seeding.
- Hero renders the CV button only when `cv_url` is set. When it isn't, "Get In
  Touch" promotes to the filled style so the hero doesn't look truncated.
- Batch 1 audit findings from this session are recorded in the Batch 1 section:
  smooth-scroll was done in CSS all along, and the design-export comparison plus
  responsive QA are still genuinely outstanding.

### 2026-08-08 (later still — Rails 8 authentication)
- Ran `bin/rails generate authentication`. The one non-obvious consequence:
  `ApplicationController` gains `before_action :require_authentication`, so the
  **public landing page started returning 403** until `PagesController` opted
  out. Worth remembering for every visitor-facing controller still to come.
- Admin credentials come from env vars, never the repo. Verified `db:seed` both
  skips cleanly without them and creates/updates the user with them.
- Verified the real sign-in flow over HTTP, not just via tests: wrong password
  redirects back to the form, correct password redirects to root and sets the
  signed `session_id` cookie.
- Removed the throwaway probe user afterwards, so the dev DB has no account with
  a password chosen by Claude.

### 2026-08-08 (later — Action Text + Active Storage)
- `bin/rails action_text:install`; both migrations applied. Verified the
  generated wiring actually resolves rather than assuming: `stylesheet_link_tag
  :app` emits `actiontext.css` alongside `application.css` and `tailwind.css`,
  and the importmap resolves `trix` + `@rails/actiontext` to real asset paths.
- `reading_time` is stored on save, not computed on read, so the articles index
  can show it without loading every body.
- `PagesController#home` uses `.with_attached_cover_image` to avoid an N+1 once
  cards start rendering images.
- Railway deployment confirmed down (HTTP 404 on the old URL) and paused
  indefinitely — the account wasn't upgraded. All work is local-only for now,
  and `PROGRESS.md`'s Reference Info section is stale about the site being live.

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
