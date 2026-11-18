# Held

Support for new mothers. She asks for specific help, family claims it, and Held notices when she may need more support.

## How it works
- **Check in:** pick a moon (new to full), add tags or one small win. Scores and notes stay on her device.
- **Requests:** she taps a specific ask. Family claims it from a link. Late claims turn rose in her orbit.
- **Wellness check:** three low check ins or two quiet days prepares a note to her person. It never includes scores.
- **Held Helper:** an AI that turns feelings into specific asks and writes the hard message. A crisis guard runs before any AI call.
- **Auth0 login** so a mother can reopen her circle on any phone.
- **Night mode, guided tour, undo, orbit view, constellation, doctor visit summary, larger text.**

## Run it (demo mode, no setup)
Open `index.html` through any static host. Everything works on one device, and "Try with demo data" fills it in.

## Turn on sync, AI, and voice (about 10 minutes)
1. Create a free project at supabase.com.
2. SQL Editor: paste `supabase/schema.sql` and run it.
3. Project Settings, API: copy the Project URL and the anon public key into the top of `index.html` (`SUPABASE_URL`, `SUPABASE_ANON_KEY`).
4. Install the Supabase CLI, link the project, then deploy the two functions:
   - `supabase functions deploy helper`
   - `supabase functions deploy speak`
5. Set secrets:
   - `supabase secrets set GEMINI_API_KEY=...` (optional `GEMINI_MODEL=...`, check the current stable Flash model name)
   - `supabase secrets set ELEVENLABS_API_KEY=... ELEVENLABS_VOICE_ID=...`
6. Deploy the folder to Vercel or Netlify. Open the Orbit tab to get the family link and QR code.

## Turn on login with Auth0 (optional, about 10 minutes)
Without it, the mother's circle is tied to an owner key stored in her browser. With it, she can log in on any phone and get her circle back. Family never needs an account.
1. In the Auth0 dashboard, create an Application of type **Single Page Application**.
2. In its settings, set **Allowed Callback URLs**, **Allowed Logout URLs**, and **Allowed Web Origins** to your deployed site address (add your local test address too). Turn on **Refresh Token Rotation**.
3. Copy the **Domain** (hostname only, no https) and **Client ID** into the top of `index.html` (`AUTH0_DOMAIN`, `AUTH0_CLIENT_ID`).
4. Auth0 needs to mark its tokens as `authenticated` for Supabase. Go to Actions, Library, Build Custom, trigger **Login / Post Login**, and use:
   ```js
   exports.onExecutePostLogin = async (event, api) => {
     api.idToken.setCustomClaim('role', 'authenticated');
     api.accessToken.setCustomClaim('role', 'authenticated');
   };
   ```
   Deploy it, then drag it into the **Login** flow under Actions, Triggers, post-login. Held sends the ID token to Supabase.
5. In Supabase, open Authentication, Third-Party Auth, add **Auth0**, and enter your tenant id (the first part of your domain) and region if it has one.
6. Re-run `supabase/schema.sql` (it is safe to run again). It adds the login ownership columns and functions.
7. Open the app, go to More, tap **Log in or sign up**. Your circle is now attached to your login.

How it works: after login, Supabase reads the signed `sub` claim from her token and matches it to her circle. Held stores only that id, never her email or password. If login is not accepted yet, the app falls back to the owner key so nothing breaks.

## Branding and assets
* `cover.jpg` is the opening splash screen (shown once per visit, tap to skip).
* `icon-192.png`, `icon-512.png`, and `apple-touch-icon.png` are the home screen icons.
* `assets/devpost-cover-1500x1000.jpg` is the Devpost thumbnail (3:2).
* `assets/github-social-1280x640.jpg` is the GitHub social preview. Upload it in the repo's Settings, under Social preview.
* Cover art credit: [add the source of the galaxy image and lettering here. If you used a stock photo, check its license.]

## Privacy and safety design
- Tables are locked. The browser only calls named functions, and a circle is reached by an unguessable id.
- Only "needs support" (true or false) is shared. Mood scores and notes never leave the device.
- The Helper only receives the words typed into it. Nothing is saved. Crisis phrases skip the AI and show 988 and the postpartum line.
- Gift links are limited to two allowed sites on the server.

## Known limits (be upfront in your pitch)
- Anyone with the family link can claim a task and type any name. There is no login for family by design.
- Without Auth0 login, the mother's owner key lives only in her browser, and clearing site data loses access to her circle. With login on, she can recover it.
- Hotline numbers and the Learn page wording should be reviewed by a clinician before real use.
- No rate limiting yet on the Helper and voice functions.

## Hackathon disclosure
Built during Hacklanta: all app code. Tools and APIs: Supabase, Auth0, Gemini API, ElevenLabs, qrcodejs. Nothing existed before the event.
