Fields above the write up

Project name: Held
Tagline: Support for new mothers that turns "let me know if you need anything" into specific help, keeps track until someone says yes, and notices when she is struggling.

Paste everything below this line into the Devpost write up box. Fill in anything in [brackets].

## Inspiration

New mothers are surrounded by people who want to help, and almost all of them hear the same sentence: "let me know if you need anything." Most never do. Exhaustion, shame, and not knowing what to ask for get in the way, and postpartum depression often goes unnoticed until it becomes serious. [Add one verified statistic here with its source, for example from the CDC. Do not use a number you have not checked.]

We noticed that the problem is not a lack of love. It is a lack of specific asks and a way to make sure someone actually shows up. We wanted to build something that makes asking for help easy, makes saying yes easy, and quietly notices when a mother may need more than a casserole. [Optional: add one personal sentence about why this matters to you.]

## What it does

Held is a support app for new mothers and the people who love them.

* **Moon check in:** she picks a moon, from new to full, adds a tag or one small win, and her check ins grow into a constellation. Her scores and notes stay on her phone.
* **Requests with a guarantee:** she taps a specific ask like dinner, a nap, or a phone call. Family claims it from a link with no account. Held tracks it until it is done, and a late claim turns rose in her orbit with a one tap nudge.
* **Orbit view:** she is the planet in the center. Family who said yes become moons, and open asks drift as faint dots.
* **Wellness check:** three low check ins in a row, or two quiet days, prepares a note to her chosen person. The note never includes her scores.
* **Held Helper (AI):** turns "I'm drowning" into two specific asks she can add with one tap, and writes the hard message for her. A crisis guard runs before any AI call and shows 988 and the postpartum line.
* **Night mode:** a dimmed screen with a breathing guide, a one tap check in, and a calm voice for 3am.
* **Family view:** family sees only a gentle summary and the open asks, never her check in details, plus tips on what to say and what to skip.
* **Extras:** a guided tour, undo after every change, a doctor visit summary she controls, larger text, and install to the home screen.

## How we built it

Held is a single page web app in plain HTML, CSS, and JavaScript, designed for phones first.

* **Supabase** provides the Postgres database and two Edge Functions. The tables are locked, and the browser only calls named functions. A circle is reached by an unguessable id, so family never needs an account. Phones stay in sync by checking every few seconds.
* **Auth0** Universal Login lets a mother reopen her circle on any phone. We send her Auth0 ID token to Supabase through third party auth, and the database matches her signed token to her circle. We store only her Auth0 user id.
* **Gemini API** powers Held Helper through an Edge Function so the key stays secret. It returns structured JSON, and the server validates every field. The AI can only suggest asks from a fixed list.
* **ElevenLabs** reads check in prompts and night mode lines aloud, also through an Edge Function. The app falls back to the phone's own voice if the service is unavailable.
* **Safety layer:** crisis phrases are caught before any AI call and show 988, the postpartum line, and 911.
* **Polish:** a moon phase scale drawn in SVG, an orbit animation that respects reduced motion, QR code sharing, a service worker for offline use, and a guided tour.

## Challenges we ran into

* **Privacy versus sharing.** Family needs to know when to help, but her check ins are private. We solved it by sharing a single true or false "could use extra support" flag and nothing else.
* **Safety.** An AI for postpartum depression can do harm. We did not build a therapy bot. The Helper cannot diagnose, only suggests from a fixed list, and crisis phrases skip the AI entirely.
* **Syncing without accounts.** We wanted family to help in one tap. That meant locking down the database and exposing only specific functions tied to an unguessable link.
* **Login with a database.** Getting Auth0 identities accepted by Supabase took care, including adding a role claim to the token and using the ID token.

## Accomplishments that we're proud of

* A complete loop that works across two real phones: ask, claim, nudge, done, and undo.
* A privacy design where the most sensitive data never leaves her device.
* A safety guard that runs before the AI, with the 988 link on every main screen.
* A demo shortcut that skips three days to show the alert and the late claim in seconds.
* A calm, finished feeling: a moon phase scale, an orbit view, a night mode, a tour, and a splash screen.

## What we learned

* Specific asks get answered and vague offers do not.
* Privacy and sharing can both be true if you decide exactly what is allowed to leave the device.
* The best use of AI here is doing a small real task, like turning feelings into asks, instead of pretending to be a therapist.
* Third party login, a locked database, and serverless functions fit together well once the token claims are right.

## What's next for Held

* Clinician and doula review of every piece of wording, including the Learn cards and hotline details.
* Partnerships with maternal health groups, doulas, and clinics.
* A moderated community for mothers, with prompts and reactions first and a clear safety plan.
* Push reminders and quiet hours, and optional family logins for people who want history.
* More languages for the Helper and the voice.

Other Devpost fields

Built with: HTML, CSS, JavaScript, Supabase (Postgres and Edge Functions), Auth0, Gemini API, ElevenLabs, qrcodejs, Claude (AI coding assistant)
Track: COX Automotive Sponsored: Social Good
Challenges: MLH Best Use of Gemini API, MLH Best Use of ElevenLabs, MLH Best Use of Auth0
