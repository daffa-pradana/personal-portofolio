# Getting a Groq API key (and using it in this app)

The AI chat feature (`ChatService`) needs an LLM API key to answer anything.
Without one it raises `ChatService::Unavailable` and the chat UI shows
"The AI assistant is temporarily unavailable." — correct behaviour, but inert.

This walks through getting a key from scratch and wiring it into local dev.

---

## Part 1 — Create the account

1. Go to **<https://console.groq.com>**.
2. Click **Sign up** (or **Start building** / **Log in** → *Sign up* depending on
   which landing page you hit).
3. Pick a sign-in method. Groq offers social sign-in (Google / GitHub) and
   email. Any is fine — social is one click fewer.
4. Complete whatever verification it asks for (email confirmation link, or the
   OAuth consent screen if you used Google/GitHub).
5. You land on the Groq Console dashboard.

> **On cost:** Groq has historically offered a free development tier that
> doesn't require a card up front, which is why it's the default provider here.
> I could not verify the current card/free-tier policy from their public docs
> while writing this (the pricing page is JavaScript-rendered), so **check what
> the signup flow actually asks you for** rather than taking that as given. If
> it does demand a card, see "Switching providers" at the bottom — the app is
> built so that's a config change, not a rewrite.

---

## Part 2 — Generate the key

1. In the console, go to **<https://console.groq.com/keys>**.
   (Also reachable from the left sidebar as **API Keys**.)
2. Click **Create API Key**.
3. Give it a recognisable name — e.g. `personal-portofolio-dev`. This is just a
   label for you; it has no effect on the key's permissions.
4. Submit. The key is generated and displayed.
5. **Copy it immediately.** API keys are conventionally shown exactly once —
   after you dismiss the dialog you can see the key's *name* and metadata but
   not the secret again. If you lose it, delete the key and make a new one.

The key looks like:

```
gsk_XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
```

The `gsk_` prefix is what a Groq key looks like — useful for spotting one in a
log or a paste where it doesn't belong.

---

## Part 3 — Use it in this app

`ChatService` reads the key from the **`GROQ_API_KEY` environment variable**
(`app/services/chat_service.rb`).

This project uses a **single gitignored `.env` file** for all local secrets,
loaded automatically by `dotenv-rails`.

### Setup (once)

```bash
cp .env.example .env
```

Then open `.env` and fill in the key:

```bash
GROQ_API_KEY=gsk_your_key_here
```

That's it. No prefixing anything onto commands — the value is picked up by all
of these:

```bash
bin/dev
bin/rails console
bin/rails runner '...'
bin/rails test
```

`.env` is gitignored, and `git add .env` is actively refused. `.env.example` is
the one tracked `.env*` file and holds placeholders only — keep it updated when
you add a new variable, so the required set stays discoverable.

### Alternative: no file at all

If you'd rather not have the secret on disk, prefix it per command instead:

```bash
GROQ_API_KEY=gsk_your_key_here bin/dev
```

Scoped to that single invocation. `.env` values win over nothing, but an
explicitly exported shell variable wins over `.env` — handy for temporarily
overriding one value without editing the file.

### Verify it's actually visible to Rails

```bash
bin/rails runner 'puts ENV["GROQ_API_KEY"].present? ? "key is set" : "NOT set"'
```

If that prints `NOT set` while `bin/dev` is running in another terminal, the
variable was set in a different shell than the one the server booted from.

---

## Part 4 — Confirm the chat works

1. Start the server with the key set (Option A/B/C above).
2. Open <http://localhost:3000> and scroll to the **Chat with AI** section
   (or click **AI Chat** in the navbar).
3. Click a suggested question, e.g. *"What's Daffa's tech stack?"*
4. You should see your question appear as a bubble, a typing indicator, then a
   grounded answer referencing the seeded knowledge entries.

If knowledge entries are missing, seed them:

```bash
bin/rails db:seed
```

(Idempotent — safe to re-run.)

### Sanity checks worth doing once

| Check | Expected |
|---|---|
| Ask something off-topic ("capital of France?") | Politely declines, redirects to Daffa-related topics |
| Ask 11 questions in one session | 11th shows the "reached the question limit" message |
| Restart `bin/dev` **without** the key | Chat shows "temporarily unavailable", no error page |

---

## Security notes

- **Never commit the key.** It's a bearer credential — anyone with it can spend
  your quota. This repo is **public**, so a committed key is effectively
  published, and git history is permanent.
- If a key is ever exposed (pasted in an issue, committed, shared in a
  screenshot), **delete it in the console and generate a new one**. Rotating is
  cheap; assuming it's fine is not.
- Use a separate key for local dev vs. any future deployment, so you can revoke
  one without breaking the other.
- The key is only ever read server-side. It is never sent to the browser.

---

## Switching providers

`ChatService` deliberately speaks the **generic OpenAI-compatible
`/chat/completions` contract** rather than anything Groq-specific, so you can
point it elsewhere without touching Ruby:

```bash
LLM_BASE_URL=https://openrouter.ai/api/v1 \
LLM_MODEL=meta-llama/llama-3.3-70b-instruct \
GROQ_API_KEY=your_other_providers_key \
bin/dev
```

Defaults live in `app/services/chat_service.rb`
(`DEFAULT_BASE_URL`, `DEFAULT_MODEL`).

Known-compatible alternatives: OpenRouter, Together.ai, Cerebras, Fireworks,
and Google Gemini's OpenAI-compat endpoint.

> The env var is still named `GROQ_API_KEY` even when pointing at another
> provider — a leftover from Groq being the default. If that bothers you once a
> switch actually happens, renaming it to something neutral like `LLM_API_KEY`
> is a one-line change.
