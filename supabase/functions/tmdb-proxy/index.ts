// Couch Potatoes — TMDB proxy edge function
//
// Proxies requests to the TMDB API with our bearer token held server-side.
// The client calls this function instead of TMDB directly so the token
// never touches the browser.
//
// Usage from the client:
//   GET {SUPABASE_URL}/functions/v1/tmdb-proxy/search/movie?query=Inception
//   (everything after /tmdb-proxy is passed straight through to TMDB)
//
// Secret required:
//   TMDB_BEARER_TOKEN — your TMDB v4 read-access token
//   Set via: supabase secrets set TMDB_BEARER_TOKEN=eyJ...
//
// Deploy:
//   supabase functions deploy tmdb-proxy --no-verify-jwt
//   (we pass --no-verify-jwt because the client uses the anon key, which
//    the Supabase SDK will include automatically in the Authorization header
//    — but we don't need to enforce it for a proxy endpoint.)

import "jsr:@supabase/functions-js/edge-runtime.d.ts";

const TMDB_BASE = "https://api.themoviedb.org/3";
const TMDB_TOKEN = Deno.env.get("TMDB_BEARER_TOKEN");

// Permissive CORS — the frontend will be served from couchpotatoes.co and
// various Cloudflare preview subdomains during development.
const CORS_HEADERS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

Deno.serve(async (req) => {
  // Handle preflight
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: CORS_HEADERS });
  }

  if (!TMDB_TOKEN) {
    return new Response(
      JSON.stringify({ error: "TMDB_BEARER_TOKEN not configured on the server" }),
      { status: 500, headers: { ...CORS_HEADERS, "Content-Type": "application/json" } }
    );
  }

  try {
    const url = new URL(req.url);
    // Strip the "/functions/v1/tmdb-proxy" prefix so we're left with the TMDB path
    // e.g. "/functions/v1/tmdb-proxy/search/movie" → "/search/movie"
    // Supabase's edge runtime may or may not include the /functions/v1 prefix
    // depending on how the request arrives, so strip both forms.
    const tmdbPath = url.pathname.replace(/^\/(functions\/v1\/)?tmdb-proxy/, "");
    const tmdbUrl = `${TMDB_BASE}${tmdbPath}${url.search}`;

    const resp = await fetch(tmdbUrl, {
      method: req.method,
      headers: {
        "Authorization": `Bearer ${TMDB_TOKEN}`,
        "Accept": "application/json",
      },
      body: req.method === "GET" || req.method === "HEAD" ? undefined : await req.text(),
    });

    const body = await resp.text();
    return new Response(body, {
      status: resp.status,
      headers: {
        ...CORS_HEADERS,
        "Content-Type": resp.headers.get("Content-Type") || "application/json",
      },
    });
  } catch (e) {
    console.error("tmdb-proxy error:", e);
    return new Response(
      JSON.stringify({ error: "proxy_error", message: String(e) }),
      { status: 500, headers: { ...CORS_HEADERS, "Content-Type": "application/json" } }
    );
  }
});
