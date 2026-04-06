# Couch Potatoes — Deploy Guide

This walks you through deploying Couch Potatoes to production the first time. You'll set up GitHub, Supabase (backend), Cloudflare Pages (frontend hosting), and point `couchpotatoes.co` at it.

Estimated time: **90 minutes total** (most of which is waiting for DNS).

---

## Phase 0 — Prerequisites

Before starting, create free accounts on each of these (5 min total):

- [ ] **GitHub** — https://github.com/signup
- [ ] **Supabase** — https://supabase.com → "Start your project" → sign in with GitHub
- [ ] **Cloudflare** — https://dash.cloudflare.com/sign-up

You'll also install two command-line tools locally:

- [ ] **git** — check with `git --version` in your terminal. Install from https://git-scm.com if missing.
- [ ] **Supabase CLI** — install instructions: https://supabase.com/docs/guides/local-development/cli/getting-started
  - macOS: `brew install supabase/tap/supabase`
  - Windows: `scoop install supabase`

You don't need to install anything for Cloudflare — we'll use the web UI.

---

## Phase 1 — Supabase setup (20 minutes)

### 1.1 Create the project

1. Go to https://supabase.com/dashboard
2. Click **"New project"**
3. Fill in:
   - **Name:** `couch-potatoes`
   - **Database Password:** Click "Generate" and **save it in your password manager**. You probably won't need it, but don't lose it.
   - **Region:** Pick the one closest to your users (e.g. `US East (North Virginia)`)
   - **Pricing Plan:** Free
4. Click **"Create new project"**. It takes ~2 minutes to provision.

### 1.2 Grab your public keys (you'll paste these into `config.js` in a bit)

1. When the project is ready, go to **Project Settings → API** (the gear icon in the sidebar, then "API")
2. Copy these two values into a temporary note:
   - **Project URL** — looks like `https://abcdxyz12345.supabase.co`
   - **Project API Keys → `anon` `public`** — a long JWT starting with `eyJ…`
3. **Do NOT copy the `service_role` key.** That one stays on the server and you never need it for the frontend.

### 1.3 Run the schema

1. In the Supabase dashboard, go to **SQL Editor** (left sidebar)
2. Click **"New query"**
3. Open `supabase/schema.sql` from this project folder, copy the whole file, paste it into the SQL Editor
4. Click **"Run"** (bottom right). You should see "Success. No rows returned."
5. Verify the table exists: go to **Table Editor** (left sidebar) → you should see a `households` table with columns `id`, `profile1`, `profile2`, `services`, `session_prefs`, `created_at`, `updated_at`.

### 1.4 Set the server-side secrets (TMDB + Anthropic keys)

Open your terminal and navigate to the project folder:

```bash
cd path/to/couch-potatoes
```

Log in to the Supabase CLI (this opens a browser to authenticate):

```bash
supabase login
```

Link this folder to your Supabase project. Get your project ref from the Supabase dashboard URL — it's the string after `/project/`, e.g. `abcdxyz12345`:

```bash
supabase link --project-ref YOUR_PROJECT_REF
```

Now set the secrets. Replace the placeholders with your actual TMDB bearer token and Anthropic API key:

```bash
supabase secrets set TMDB_BEARER_TOKEN=eyJ_your_tmdb_token_here
supabase secrets set ANTHROPIC_API_KEY=sk-ant-your_anthropic_key_here
```

Verify they're set:

```bash
supabase secrets list
```

You should see both listed (values will be hidden, that's correct).

### 1.5 Deploy the edge functions

Still in the project folder:

```bash
supabase functions deploy tmdb-proxy --no-verify-jwt
supabase functions deploy claude-proxy --no-verify-jwt
```

The `--no-verify-jwt` flag lets the proxies accept requests from the browser using just the anon key. Each deploy takes ~30 seconds.

### 1.6 Quick smoke test

Test the TMDB proxy from your terminal (replace `YOUR_PROJECT_REF`):

```bash
curl "https://YOUR_PROJECT_REF.supabase.co/functions/v1/tmdb-proxy/movie/popular?language=en-US"
```

You should get back a JSON response with popular movies. If you see `{"error":"TMDB_BEARER_TOKEN not configured"}`, revisit step 1.4.

✅ **Phase 1 complete.** Your backend is live.

---

## Phase 2 — Frontend config (5 minutes)

Open `config.js` in the project folder and replace the two placeholders with your Supabase Project URL and anon key from step 1.2:

```js
window.COUCH_POTATOES_CONFIG = {
  SUPABASE_URL: "https://abcdxyz12345.supabase.co",
  SUPABASE_ANON_KEY: "eyJ_your_anon_key_here",
};
```

Save the file. That's all the frontend needs.

---

## Phase 3 — Push to GitHub (10 minutes)

### 3.1 Create a new repo

1. Go to https://github.com/new
2. **Repository name:** `couch-potatoes`
3. **Visibility:** Private is fine (you can flip it public later)
4. **Don't** initialize with a README, .gitignore, or license — we're pushing existing code
5. Click **"Create repository"**

GitHub will show you a page with setup instructions. Keep that tab open.

### 3.2 Initialize git locally and push

In your terminal, from the project folder:

```bash
git init
git add .
git commit -m "Initial Couch Potatoes deploy"
git branch -M main
git remote add origin https://github.com/YOUR_USERNAME/couch-potatoes.git
git push -u origin main
```

GitHub may ask you to authenticate the first time. On most systems the easiest path is to install the [GitHub CLI](https://cli.github.com) (`brew install gh` on Mac) and run `gh auth login` before `git push`.

Verify on GitHub: refresh your repo page, you should see all your files.

---

## Phase 4 — Cloudflare Pages (frontend hosting) (15 minutes)

### 4.1 Connect your repo

1. Go to https://dash.cloudflare.com → **Workers & Pages** (left sidebar) → **Create application** → **Pages** tab → **Connect to Git**
2. Authenticate with GitHub and give Cloudflare access to your `couch-potatoes` repo
3. Select the repo and click **"Begin setup"**
4. Configure build:
   - **Project name:** `couch-potatoes`
   - **Production branch:** `main`
   - **Framework preset:** `None`
   - **Build command:** *(leave blank)*
   - **Build output directory:** `/`
5. Click **"Save and Deploy"**

First deploy takes ~1 minute. When it's done, Cloudflare gives you a URL like `https://couch-potatoes.pages.dev`. Open it — you should see the app.

✅ **If you can pick genres and get recommendations, you're 95% done.** The app is live on Cloudflare's free subdomain.

---

## Phase 5 — Custom domain (couchpotatoes.co) (30 minutes including DNS propagation)

### 5.1 Add the domain to Cloudflare

1. Cloudflare dashboard → **Websites** (left sidebar) → **Add a site**
2. Enter `couchpotatoes.co`, click **Continue**
3. Choose the **Free** plan, click **Continue**
4. Cloudflare will scan your current DNS records. Review them, click **Continue**
5. Cloudflare shows you two **nameservers** (e.g. `maya.ns.cloudflare.com` and `rick.ns.cloudflare.com`)

### 5.2 Point your domain registrar at Cloudflare

Go to whoever you bought `couchpotatoes.co` from (GoDaddy, Namecheap, Porkbun, etc.) and:
1. Find the DNS/Nameservers settings for the domain
2. Change the nameservers from the default to the two Cloudflare nameservers you just copied
3. Save

**This can take anywhere from 5 minutes to 24 hours to propagate.** Cloudflare will email you when it's done.

### 5.3 Connect the domain to your Pages project

Once Cloudflare confirms the domain is active:

1. Dashboard → **Workers & Pages** → your `couch-potatoes` project → **Custom domains** tab → **Set up a custom domain**
2. Enter `couchpotatoes.co`, click **Continue** → **Activate domain**
3. (Optional but recommended) Also add `www.couchpotatoes.co` so both work

SSL is automatic — Cloudflare issues a cert within ~1 minute.

✅ **Phase 5 complete.** https://couchpotatoes.co is live.

---

## Phase 6 — Verify end-to-end

Open https://couchpotatoes.co in a fresh browser (incognito is fine now — no keys needed!) and run through:

- [ ] App loads, no "Dev mode — API keys missing" banner
- [ ] Pick genres → you see recommendations
- [ ] Create a partner share link, open it in a different browser → partner onboarding works
- [ ] Partner completes their profile → you see the couple recommendations

If any of those fail, check:
- **Browser console** (F12 → Console) for errors
- **Supabase → Edge Functions → Logs** for proxy errors
- **Cloudflare → your project → Deployments → View details** for build errors

---

## Making changes after launch

Any change you push to GitHub's `main` branch auto-deploys to Cloudflare Pages. Workflow:

```bash
# Make your edits in index.html or wherever
git add .
git commit -m "describe the change"
git push
```

Cloudflare picks it up within ~30 seconds and redeploys automatically. The old version stays up until the new one is ready.

If you change an edge function, redeploy it from the CLI:

```bash
supabase functions deploy tmdb-proxy --no-verify-jwt
# or
supabase functions deploy claude-proxy --no-verify-jwt
```

---

## Monthly costs

- **Supabase Free tier:** 500 MB database, 2 GB egress, 500k edge function invocations. Zero cost unless you blow past those (you won't for a while).
- **Cloudflare Pages Free tier:** Unlimited sites, 500 builds/month, unlimited bandwidth. Zero cost.
- **Claude API:** ~$0.001 per recommendation batch with Haiku. For 100 users × 5 sessions/week × 1 Claude call each, that's ~$2/month. Set billing alerts on https://console.anthropic.com.
- **TMDB:** Free (non-commercial use; if Couch Potatoes starts monetizing, check their commercial license terms).
- **Domain:** Whatever you pay annually for `couchpotatoes.co` (~$10-30/yr).

**Total ongoing:** roughly $0-5/month at early-launch scale.

---

## Questions for later

Things to revisit after you've launched and gotten real user feedback:

1. **Real auth.** Replace the "household ID as shared secret" model with Supabase Auth (magic link is free and one config flip). Update the RLS policies to check `auth.uid()` against a `household_members` table.
2. **Rate limiting on the edge functions.** If someone gets hold of your anon key and hammers the Claude proxy, they could run up your bill. Add a simple per-IP rate limit (e.g. 30 requests/minute) to `claude-proxy`.
3. **Usage tracking.** A `sessions` table logging each recommendation batch, for basic analytics and anomaly detection.
4. **Password-protected edge functions for sensitive operations.** Right now anyone with the anon key can call the Claude proxy. This is fine at small scale with rate limiting, but becomes a problem at bigger scale.
