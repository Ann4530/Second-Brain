/**
 * Cloud Functions for Second Brain.
 *
 * These proxy Groq (Llama 3.3 70B, zero data retention) so the API key never
 * ships in the app. Used as the FALLBACK engine (low-RAM devices) and for
 * high-quality premium weekly recaps. On-device is the primary engine.
 *
 * Set the key once:  firebase functions:secrets:set GROQ_API_KEY
 */
import { onCall, HttpsError } from "firebase-functions/v2/https";
import { defineSecret } from "firebase-functions/params";
import admin from "firebase-admin";

admin.initializeApp();

const GROQ_API_KEY = defineSecret("GROQ_API_KEY");
const GROQ_URL = "https://api.groq.com/openai/v1/chat/completions";
const MODEL = "llama-3.3-70b-versatile";

const PERSONA = `You are a warm, perceptive reflection companion inside a private journaling app.
Given a short journal entry you (1) write a brief 2-4 sentence reflection that mirrors the
person's feelings and surfaces one specific insight, and (2) offer ONE small concrete nudge.
You are NOT a therapist; never diagnose. Be kind, honest, concise.`;

async function groqJson(messages, secret) {
  const res = await fetch(GROQ_URL, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Authorization: `Bearer ${secret}`,
    },
    body: JSON.stringify({
      model: MODEL,
      temperature: 0.5,
      response_format: { type: "json_object" },
      messages,
    }),
  });
  if (!res.ok) {
    const body = await res.text();
    throw new HttpsError("internal", `Groq error ${res.status}: ${body}`);
  }
  const data = await res.json();
  const content = data?.choices?.[0]?.message?.content ?? "{}";
  return JSON.parse(content);
}

/** Reflect on one entry. Returns {reflection, nudge, metadata}. */
export const groqReflect = onCall(
  { secrets: [GROQ_API_KEY], region: "us-central1" },
  async (req) => {
    if (!req.auth) throw new HttpsError("unauthenticated", "Sign in required.");
    const text = (req.data?.text ?? "").toString().slice(0, 8000);
    if (!text.trim()) throw new HttpsError("invalid-argument", "Empty entry.");
    const language = req.data?.language;

    const prompt = `${PERSONA}
${language ? `Respond in: ${language}.` : ""}
Journal entry:
"""${text}"""

Return ONLY JSON:
{"reflection":"string","nudge":"string","metadata":{"mood":"string","moodScore":-3,"energy":3,"topics":[],"people":[],"activities":[]}}`;

    return groqJson(
      [
        { role: "system", content: PERSONA },
        { role: "user", content: prompt },
      ],
      GROQ_API_KEY.value()
    );
  }
);

/** Premium weekly narrative from precomputed stats + snippets. */
export const groqWeeklyNarrative = onCall(
  { secrets: [GROQ_API_KEY], region: "us-central1" },
  async (req) => {
    if (!req.auth) throw new HttpsError("unauthenticated", "Sign in required.");
    const stats = req.data?.stats ?? {};
    const snippets = Array.isArray(req.data?.snippets) ? req.data.snippets : [];

    const prompt = `${PERSONA}
Computed stats about the person: ${JSON.stringify(stats)}
Entry snippets:
${snippets.map((s) => `- ${s}`).join("\n")}

Surface 2-3 genuine, specific patterns (tie mood to activities/weekdays), then ONE nudge.
Return ONLY JSON: {"headline":"<=90 chars","narrative":"2-4 short paragraphs"}`;

    return groqJson(
      [
        { role: "system", content: PERSONA },
        { role: "user", content: prompt },
      ],
      GROQ_API_KEY.value()
    );
  }
);

/** GDPR-style account deletion: wipe Firestore data + the auth user. */
export const deleteAccount = onCall({ region: "us-central1" }, async (req) => {
  if (!req.auth) throw new HttpsError("unauthenticated", "Sign in required.");
  const uid = req.auth.uid;
  const db = admin.firestore();

  // Delete subcollections (entries, recaps) then the user doc.
  for (const sub of ["entries", "recaps"]) {
    const snap = await db.collection("users").doc(uid).collection(sub).get();
    const batch = db.batch();
    snap.docs.forEach((d) => batch.delete(d.ref));
    await batch.commit();
  }
  await db.collection("users").doc(uid).delete().catch(() => {});
  await admin.auth().deleteUser(uid);
  return { ok: true };
});
