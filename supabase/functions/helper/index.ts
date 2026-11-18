// Held Helper: Gemini powered, JSON only, with a crisis guard.
// Deploy: supabase functions deploy helper
// Secrets: supabase secrets set GEMINI_API_KEY=your_key   (optional: GEMINI_MODEL=...)

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};
const ALLOWED = ["nap", "dinner", "shower", "laundry", "groceries", "call", "visit"];
const CRISIS = /(kill myself|killing myself|suicid|end it all|end my life|want to die|wanna die|better off (dead|without me)|hurt myself|harm myself|hurting myself|cut myself|(hurt|harm|hurting|harming|shake|shaking) (my|the) (baby|child|kid|newborn)|can'?t go on|don'?t want to (be here|live|exist)|no reason to live|hearing voices)/i;
// Check the current Gemini docs for the latest stable Flash model name and set GEMINI_MODEL if needed.
const MODEL = Deno.env.get("GEMINI_MODEL") ?? "gemini-2.5-flash";

const RULES = `You are Held Helper, an AI inside a support app for new mothers. You are not a person, not a therapist, and not a doctor.
Never diagnose. Never give medical, medication, or infant health advice. Never claim to remember her or to be her friend.
Keep replies warm, plain, and under 70 words. No lists. Gently point her toward the people in her life and, when it fits, a doctor or midwife.
If the person mentions suicide, self harm, harming a baby, wanting to die, or hearing voices, set "crisis" to true and leave "reply" empty.
Output only JSON in this shape: {"reply": string, "asks": string[], "draft": string or null, "crisis": boolean}`;

const MOM_PROMPT = `${RULES}
You are talking to the mother. Choose up to 2 ids for specific help she could ask for, only from this list:
nap (someone watches the baby so she can sleep), dinner, shower (someone holds the baby), laundry, groceries, call (someone listens, no advice), visit (short visit, no hosting).
If she asks for a message to her person, or a message would help, put it in "draft": first person, under 50 words, one specific ask, no greeting, no mention of scores or diagnoses.`;

const FAMILY_PROMPT = `${RULES}
You are talking to a family member or friend who wants to support a new mother. Give 2 or 3 specific, practical things they can do this week.
Do not ask for or reveal anything private about her. Leave "asks" as an empty array and "draft" as null.`;

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), { status, headers: { ...cors, "Content-Type": "application/json" } });

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  if (req.method !== "POST") return json({ error: "POST only" }, 405);

  let body: any;
  try { body = await req.json(); } catch { return json({ error: "bad json" }, 400); }

  const role = body.role === "family" ? "family" : "mom";
  const message = String(body.message ?? "").slice(0, 600);
  if (!message.trim()) return json({ error: "empty message" }, 400);

  // Crisis guard runs before the model is ever called.
  if (CRISIS.test(message)) return json({ crisis: true, reply: "", asks: [], draft: null });

  const key = Deno.env.get("GEMINI_API_KEY");
  if (!key) return json({ error: "not configured" }, 500);

  let history = (Array.isArray(body.history) ? body.history : []).slice(-6).map((h: any) => ({
    role: h.from === "me" ? "user" : "model",
    parts: [{ text: String(h.text ?? "").slice(0, 600) }],
  }));
  while (history.length && history[0].role !== "user") history.shift();

  const res = await fetch(`https://generativelanguage.googleapis.com/v1beta/models/${MODEL}:generateContent`, {
    method: "POST",
    headers: { "Content-Type": "application/json", "x-goog-api-key": key },
    body: JSON.stringify({
      systemInstruction: { parts: [{ text: role === "family" ? FAMILY_PROMPT : MOM_PROMPT }] },
      contents: [...history, { role: "user", parts: [{ text: message }] }],
      generationConfig: { responseMimeType: "application/json", temperature: 0.6, maxOutputTokens: 1500 },
    }),
  });
  if (!res.ok) return json({ error: "model error" }, 502);

  const data = await res.json();
  const raw = data?.candidates?.[0]?.content?.parts?.[0]?.text ?? "";
  let out: any;
  try { out = JSON.parse(raw); } catch { return json({ error: "bad model output" }, 502); }

  const asks = role === "mom" && Array.isArray(out.asks)
    ? out.asks.filter((a: string) => ALLOWED.includes(a)).slice(0, 2) : [];
  const crisis = out.crisis === true;
  return json({
    crisis,
    reply: crisis ? "" : String(out.reply ?? "").slice(0, 700),
    asks,
    draft: role === "mom" && out.draft ? String(out.draft).slice(0, 400) : null,
  });
});
