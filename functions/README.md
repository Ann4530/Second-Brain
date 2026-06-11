# Cloud Functions — Groq proxy + account deletion

These keep the **Groq API key off the device**. The app calls `groqReflect` /
`groqWeeklyNarrative` only as a fallback (low-RAM devices) or for premium
cloud-quality weekly recaps. On-device Gemma is the primary engine.

## Setup

```powershell
# from project root
npm install -g firebase-tools          # Node is already installed
firebase login
firebase init functions                # choose JavaScript, existing project; or reuse this folder

cd functions
npm install

# Store the Groq key as a secret (never commit it)
firebase functions:secrets:set GROQ_API_KEY   # paste your key from console.groq.com

# Run locally
npm run serve     # emulator
# Deploy
npm run deploy
```

## Functions

| Function | Purpose |
|---|---|
| `groqReflect` | Reflect on one entry → `{reflection, nudge, metadata}` (Llama 3.3 70B, JSON mode). |
| `groqWeeklyNarrative` | Premium weekly "patterns about you" from precomputed stats + snippets. |
| `deleteAccount` | Wipes the user's Firestore data + auth user (privacy / GDPR). |

## Notes

- Model: `llama-3.3-70b-versatile`. Groq does **not** retain data for inference by
  default (good for sensitive journal text); enable ZDR on the account for the
  strongest guarantee.
- All callable functions require Firebase Auth (`req.auth`).
- Enforce the free 1/day cap here too (count today's entries for the uid) — don't
  rely on the client check alone.
