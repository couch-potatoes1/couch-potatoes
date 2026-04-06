// Couch Potatoes — Claude (Anthropic) proxy edge function
//
// Proxies requests to the Anthropic Messages API with our API key held
// server-side. The client POSTs the same body it would send directly to
// Anthropic, and this function forwards it.
//
// Usage from the client:
//   POST {SUPABASE_URL}/functions/v1/claude-proxy
//   Body: the same JSON you'd send to https://api.anthropic.com/v1/messages
//
// Secrets required:
//   ANTHROPIC_API_KEY — your Claude API key
//   Set via: supabase secrets set ANTHROPIC_API_KEY=sk-ant-...
//
// Deploy:
//   supabase functions deploy claude-proxy --no-verify-jwt

import "jsr:@supabase/functions-js/edge-runtime.d.ts";

const ANTHROPIC_API = "https://api.anthropic.com/v1/messages";
const ANTHROPIC_KEY = Deno.env.get("ANTHROPIC_API_KEY");

const CORS_HEADERS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: CORS_HEADERS });
  }

  if (req.method !== "POST") {
    return new Response(
      JSON.stringify({ error: "method_not_allowed" }),
      { status: 405, headers: { ...CORS_HEADERS, "Content-Type": "application/json" } }
    );
  }

  if (!ANTHROPIC_KEY) {
    return new Response(
      JSON.stringify({ error: "ANTHROPIC_API_KEY not configured on the server" }),
      { status: 500, headers: { ...CORS_HEADERS, "Content-Type": "application/json" } }
    );
  }

  try {
    const body = await req.text();

    // NOTE: If you want to enforce caps (e.g. max_tokens, specific models),
    // parse + rewrite the body here. For now we pass it through untouched.

    const resp = await fetch(ANTHROPIC_API, {
      method: "POST",
      headers: {
        "x-api-key": ANTHROPIC_KEY,
        "anthropic-version": "2023-06-01",
        "Content-Type": "application/json",
      },
      body,
    });

    const respBody = await resp.text();
    return new Response(respBody, {
      status: resp.status,
      headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
    });
  } catch (e) {
    console.error("claude-proxy error:", e);
    return new Response(
      JSON.stringify({ error: "proxy_error", message: String(e) }),
      { status: 500, headers: { ...CORS_HEADERS, "Content-Type": "application/json" } }
    );
  }
});
