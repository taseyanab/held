// Held voice: ElevenLabs text to speech, called from the browser through this function so the key stays secret.
// Deploy: supabase functions deploy speak
// Secrets: supabase secrets set ELEVENLABS_API_KEY=your_key ELEVENLABS_VOICE_ID=your_voice_id

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  if (req.method !== "POST") return new Response("POST only", { status: 405, headers: cors });

  let body: any;
  try { body = await req.json(); } catch { return new Response("bad json", { status: 400, headers: cors }); }
  const text = String(body.text ?? "").slice(0, 500);
  if (!text.trim()) return new Response("empty", { status: 400, headers: cors });

  const key = Deno.env.get("ELEVENLABS_API_KEY");
  const voice = Deno.env.get("ELEVENLABS_VOICE_ID");
  if (!key || !voice) return new Response("not configured", { status: 500, headers: cors });

  const r = await fetch(`https://api.elevenlabs.io/v1/text-to-speech/${voice}?output_format=mp3_44100_128`, {
    method: "POST",
    headers: { "xi-api-key": key, "Content-Type": "application/json" },
    body: JSON.stringify({ text, model_id: "eleven_multilingual_v2" }),
  });
  if (!r.ok) return new Response("voice error", { status: 502, headers: cors });
  return new Response(r.body, { headers: { ...cors, "Content-Type": "audio/mpeg" } });
});
