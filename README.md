# Business Spew 🔥

> *"Leveraged Synergies"* — a phrase that sounds important and means absolutely nothing.

Business Spew (BS) is a corporate jargon generator — a satirical engine that produces
authentic-sounding, content-free business language on demand. It is a direct descendant
of **JIVE**, a PC shareware application written in Borland Turbo Pascal in the mid-1990s
that transcribed text into Ebonics and other linguistic flavors. Wilson A. Rogers took
that idea online, rewrote it in the original LiveScript running directly in the browser,
and together we evolved it into Business Spew — named partly for the obvious acronym,
and partly for a phrase Wilson heard in a meeting and could never quite shake.

Wilson succumbed to leukemia in 2005. This version — rebuilt from scratch in Ruby,
backed by AWS S3, and deployed on Fly.io — is both a tribute to him and a personal
legacy project. He would have had opinions about the tooling. They would have been
worth hearing.

The full story lives at [leveragedsynergies.com](https://leveragedsynergies.com).

---

## Project Overview

Business Spew is a single Sinatra application (`Ruby 4.0.5`) that serves:

- A tribute landing page at `leveragedsynergies.com`
- An interactive playground at `bs.leveragedsynergies.com`
- A JSON API at `api.leveragedsynergies.com`

Vocabulary is stored as JSON files in AWS S3 and loaded into memory at startup.
Sentences are constructed by randomly sampling `prefixes`, `verbs`, `nouns`,
and `connectors` from whichever topic category the caller requests.

### Key files

```
.
├── app.rb                  # Sinatra application — all routes
├── config.ru               # Rack boot file
├── Procfile                # Fly.io process definition
├── fly.toml                # Fly.io deployment configuration
├── Gemfile
├── lib/
│   ├── spew_generator.rb   # Sentence/paragraph generation logic
│   └── s3_data_store.rb    # AWS S3 vocabulary loader
└── views/
    ├── landing.erb         # leveragedsynergies.com — tribute & history
    ├── playground.erb      # bs.leveragedsynergies.com — interactive UI
    ├── index.erb           # Live spew demo with feature overview
    └── api_docs.erb        # /api-docs — full API reference
```

---

## S3 Vocabulary Structure

Vocabulary files live in the `lexicon/` prefix of the `businessspew` S3 bucket.
Each file represents one topic category.

```
businessspew/
└── lexicon/
    ├── tech.json
    ├── crypto.json
    └── ai.json
```

### File format

Every vocabulary file follows this structure:

```json
{
  "category": "tech",
  "nouns":      [ "synergy playbooks", "stakeholder maps", "ROIs", ... ],
  "verbs":      [ "leverage", "actualize", "cross-pollinate", ... ],
  "connectors": [ "therefore", "notwithstanding", "given that", ... ],
  "prefixes":   [ "We must seize the moment and", "The bottom line is that we need to", ... ]
}
```

| Key | Role in sentence generation |
|---|---|
| `category` | Must match the filename (without `.json`) |
| `prefixes` | Opens the sentence — sets the tone |
| `verbs` | Action word following the prefix |
| `nouns` | Subject or object of the action |
| `connectors` | Optional clause joiner (used ~50% of the time) |

A generated sentence follows this pattern:

```
<prefix> <verb> <noun>[, <connector> <verb> <noun>].
```

Example:
> *We must seize the moment and leverage synergy playbooks, therefore actualize our stakeholder maps.*

---

## Adding a New Topic

1. **Create the vocabulary file** following the format above.
   Name it `<topic>.json` where `<topic>` is lowercase, no spaces
   (e.g. `finance.json`, `hr.json`, `legal.json`).

2. **Upload to S3** under the `lexicon/` prefix:
   ```bash
   aws s3 cp finance.json s3://businessspew/lexicon/finance.json
   ```

3. **Trigger a vocabulary reload** — the app caches vocabulary at startup
   and will not reflect S3 changes until this is called:
   ```bash
   curl -X POST https://api.leveragedsynergies.com/admin/reload
   ```

4. **Verify** the new category appears in the response:
   ```json
   { "status": "ok", "categories": ["tech", "crypto", "ai", "finance"] }
   ```

No code changes, no redeployment required. The S3 listing and reload handle everything.

> **Tip:** Add a shell alias to your `.zshrc` / `.bashrc` so the reload is always at hand:
> ```bash
> alias bs-reload="curl -s -X POST https://api.leveragedsynergies.com/admin/reload | ruby -r json -e 'puts JSON.pretty_generate(JSON.parse(STDIN.read))'"
> ```

---

## API Reference

Full interactive documentation: [bs.leveragedsynergies.com/api-docs](https://bs.leveragedsynergies.com/api-docs)

Base URL: `https://api.leveragedsynergies.com`

All endpoints return JSON. No authentication required (except `/admin/reload`).

### Endpoints

| Method | Path | Description |
|---|---|---|
| `GET` | `/api` | Service status, loaded categories, available routes |
| `GET` | `/health` | Liveness check — `200 ok` or `503 degraded` |
| `GET` | `/api/:topic` | Generate spew for a specific topic |
| `GET` | `/api/:topic/:sentences?/:paragraphs?/:title?` | Generate with optional parameters |
| `GET` | `/api/:sentences?/:paragraphs?/:title?` | Generate from a random topic |
| `POST` | `/spew` | Generate via JSON request body |
| `POST` | `/admin/reload` | Reload vocabulary from S3 |

### Parameters

| Parameter | Type | Default | Description |
|---|---|---|---|
| `topic` | String | random | Must match a loaded category name |
| `sentences` | Integer | 3 | Sentences per paragraph (1–10) |
| `paragraphs` | Integer | 1 | Number of paragraphs (1–10) |
| `title` | String | generated | Auto-generated from topic vocabulary if omitted |

### Example requests

```bash
# Service status
curl https://api.leveragedsynergies.com/api

# Single sentence, tech topic
curl https://api.leveragedsynergies.com/api/tech/1

# Two paragraphs, three sentences each, AI topic
curl https://api.leveragedsynergies.com/api/ai/3/2

# Via POST with JSON body
curl -X POST https://api.leveragedsynergies.com/spew \
  -H "Content-Type: application/json" \
  -d '{ "topic": "crypto", "sentences": 2, "paragraphs": 3 }'
```

### Error responses

| Status | Meaning |
|---|---|
| `404` | Unknown topic — response includes `available_topics` list |
| `503` | Vocabulary unavailable — S3 unreachable at startup |
| `502` | Reload failed — S3 unreachable at time of reload request |

---

## Operational Notes

### Vocabulary is cached at startup

`SpewGenerator` loads all `lexicon/*.json` files from S3 once when the process
starts. Changes to S3 are not reflected until a reload is triggered.

### After any S3 vocabulary update

```bash
curl -X POST https://api.leveragedsynergies.com/admin/reload
```

### Health check

```bash
curl https://api.leveragedsynergies.com/health
```

Returns `{ "status": "ok" }` when vocabulary is loaded and the app is healthy.
Returns `503` with `{ "status": "degraded", "reason": "vocabulary not loaded" }`
if S3 was unreachable at startup. A reload will recover the app without a restart.

### Checking what is loaded

```bash
curl https://api.leveragedsynergies.com/api
```

The `categories` field lists every topic currently in memory.

### Admin route

`POST /admin/reload` is currently unauthenticated. Do not expose it publicly
without adding authentication (API key header or HTTP Basic Auth).
See the `TODO` comment in `app.rb` for implementation guidance.

---

## Environment Variables

| Variable | Description |
|---|---|
| `AWS_REGION` | S3 region (e.g. `us-east-1`) |
| `AWS_ACCESS_KEY_ID` | AWS credentials |
| `AWS_SECRET_ACCESS_KEY` | AWS credentials |
| `AWS_S3_BUCKET` | Bucket name (e.g. `businessspew`) |
| `RACK_ENV` | `development` or `production` |

Set locally in `.env` (loaded via `dotenv`). Set in production via:
```bash
fly secrets set AWS_ACCESS_KEY_ID=... AWS_SECRET_ACCESS_KEY=... AWS_REGION=us-east-1 AWS_S3_BUCKET=businessspew
```

---

*In memory of Wilson A. Rogers — the man who took a silly idea and made it better.*

:: updated July 2026 when Thom resurrected the old app as a tribute to Wilson and a _final_ project in his legacy. ::