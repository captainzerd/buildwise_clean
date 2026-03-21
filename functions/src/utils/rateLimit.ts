// Per-UID rate limiter backed by Firestore.
// Stores a counter document at rate_limits/{uid}_{action}.
// Counter resets after windowSeconds. Throws resource-exhausted if exceeded.
//
// Usage:
//   await rateLimit(uid, 'initPaystack', 10, 3600);

import * as admin from "firebase-admin";
import { HttpsError } from "firebase-functions/v2/https";

const db = admin.firestore();

export async function rateLimit(
  uid: string,
  action: string,
  maxCalls: number,
  windowSeconds: number
): Promise<void> {
  const docId = `${uid}_${action}`;
  const ref = db.collection("rate_limits").doc(docId);

  await db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    const now = Date.now();
    const windowMs = windowSeconds * 1000;

    if (!snap.exists) {
      tx.set(ref, { count: 1, windowStart: now });
      return;
    }

    const data = snap.data()!;
    const windowStart = (data.windowStart as number) ?? 0;
    const count = (data.count as number) ?? 0;

    if (now - windowStart > windowMs) {
      // Window expired — reset counter
      tx.set(ref, { count: 1, windowStart: now });
      return;
    }

    if (count >= maxCalls) {
      throw new HttpsError(
        "resource-exhausted",
        `Rate limit exceeded for ${action}. Try again later.`
      );
    }

    tx.update(ref, { count: count + 1 });
  });
}
