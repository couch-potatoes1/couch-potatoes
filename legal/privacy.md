# Privacy Policy

**Last updated:** April 6, 2026

This is the short, plain-English version of how Couch Potatoes handles your data. The TL;DR is: we collect the minimum we need to make the app work, we don't sell anything to anyone, we don't run analytics or tracking pixels, and you can delete your data by emailing us.

## What we collect

When you use Couch Potatoes, we store:

- **A household ID** — a random string that identifies your household so you and your partner can sync.
- **First names** — the names you and your partner enter during onboarding (e.g. "Alex" and "Chris"). These are only shown inside your own household.
- **Favorites** — the movies and TV shows you mark as favorites to help us learn your taste.
- **Watch state** — which movies and shows you've seen, liked, dismissed, or saved for later.
- **Session preferences** — your "tonight's vibe" picks (mood, runtime, etc.).
- **Generated taste profile** — a short summary of your viewing preferences derived from your favorites.

That's it. We do **not** collect your email, phone number, address, payment info, IP address (beyond standard server logs), or any other personally identifying information.

## What we do NOT collect

- No analytics (no Google Analytics, no Mixpanel, no Hotjar, no pixels)
- No advertising trackers
- No third-party cookies
- No social media integrations
- No payment information
- No location data

## Where your data lives

Your household data is stored in a Postgres database hosted by **Supabase** (running on AWS in the **us-east-1** region, North Virginia, United States). Movie and TV metadata (titles, posters, descriptions) is fetched from **The Movie Database (TMDB)** when you use the app.

When the app generates a personalized "why you'd like this" note for a recommendation, the request goes through our server-side proxy to **Anthropic's Claude API**. The prompt sent to Anthropic contains your first name and the title of the movie or show — nothing else. Anthropic processes the request to generate the response and does not use it to train models. See Anthropic's privacy policy for details.

## Cookies and local storage

Couch Potatoes uses your browser's **localStorage** to remember your household ID so you don't have to sign in every time you open the app. This is the only thing we store in your browser, and it's strictly necessary for the app to work — under GDPR and similar laws, "strictly necessary" storage doesn't require a consent banner. We do not use any tracking cookies, advertising cookies, or analytics cookies.

If you clear your browser's site data, your local household ID will be removed and you'll need to enter it again to get back into your household.

## A note on access

Your household ID is the only credential needed to access your household. Anyone you share it with — or anyone who sees it on your screen or in your browser — will have full access to view and modify your household's data, including your favorites, watch state, and profile names. Treat it like a password: only share it with the partner you're watching with, and don't post it publicly.

We can't currently revoke access for someone you've shared your household ID with. If you need to "kick someone out," email us and we'll help you migrate to a new household ID.

## Sharing your data

We don't share your data with anyone. We don't sell it. We don't license it. The only third parties that ever touch your data are:

- **Supabase** — stores it (they're our database host)
- **TMDB** — provides the movie metadata you see (they don't receive your data)
- **Anthropic** — processes "why you'd like this" prompts (they receive only your first name + a movie title)
- **Cloudflare** — serves the website (standard CDN logs)

## Your rights

You can:

- **See your data** — email us and we'll send you everything we have on your household.
- **Delete your data** — email us with your household ID and we'll permanently delete it from the database.
- **Stop using the app** — at any time, for any reason. Clearing your browser's site data removes your local copy immediately.

## Children

Couch Potatoes is not directed at children under 13 and we do not knowingly collect data from them. If you believe a child has used the app and provided data, email us and we'll delete it.

## Changes

If we change how we handle data, we'll update this page and bump the "Last updated" date. If we ever start collecting more than what's listed here, we'll make it obvious before doing so.

## Contact

Questions, concerns, data requests? Email **help@couchpotatoes.co**.
