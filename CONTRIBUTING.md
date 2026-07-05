# Contributing

This is a personal project, but it follows a proper git workflow to keep `main`
always deployable and to demonstrate good engineering practice.

## Workflow

1. **Never commit directly to `main`.** It is protected — direct pushes are rejected.
2. Create a branch off `main` using the naming convention below.
3. Push the branch and open a Pull Request.
4. Wait for CI to pass (`scan_ruby`, `scan_js`, `lint`, `test`).
5. Merge via **squash** or **rebase** (merge commits are disabled to keep history linear).
6. The branch is auto-deleted on merge.

```bash
git switch main && git pull
git switch -c feat/blog-article-model
# ...work...
git push -u origin feat/blog-article-model
gh pr create --fill
```

## Branch naming

| Prefix       | Use for                              | Example                     |
|--------------|--------------------------------------|-----------------------------|
| `feat/`      | New feature or enhancement           | `feat/ai-chat-endpoint`     |
| `fix/`       | Bug fix                              | `fix/mobile-nav-overflow`   |
| `chore/`     | Tooling, deps, config, housekeeping  | `chore/branch-protection`   |
| `docs/`      | Documentation only                   | `docs/readme-setup`         |
| `refactor/`  | Code change with no behavior change  | `refactor/pages-partials`   |

## Local guard

Run once after cloning to enable the local pre-push hook that blocks accidental
direct pushes to `main`:

```bash
git config core.hooksPath .githooks
```

## Deployment

`main` is the deploy branch. A merge to `main` is what gets deployed to Railway.
Deployment is currently paused until **25 July 2026**; until then, merges to `main`
are code-only and are not shipped to the server.
