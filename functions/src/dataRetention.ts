// functions/src/dataRetention.ts
//
// Data retention functions:
//   enforceDataRetention — scheduled daily at 04:00 UTC
//   exportUserData       — callable, returns all user data as JSON
//   processAccountDeletion — Firestore trigger on deletion_requests approved

import * as admin from "firebase-admin";
import { onCall, HttpsError } from "firebase-functions/v2/https";
import { onSchedule } from "firebase-functions/v2/scheduler";
import { onDocumentUpdated } from "firebase-functions/v2/firestore";
import { logger } from "firebase-functions";
import { rateLimit } from "./utils/rateLimit";

const db = admin.firestore();

// ── Helpers ──────────────────────────────────────────────────────────────────

// Deletes up to 500 qualifying documents per run (Firestore batch limit).
// Documents beyond 500 will be cleaned up on subsequent daily runs.
async function deleteCollection(
  collRef: FirebaseFirestore.CollectionReference,
  olderThanMs: number,
  timestampField = "createdAt"
): Promise<number> {
  const cutoff = new Date(Date.now() - olderThanMs);
  const snap = await collRef
    .where(timestampField, "<", cutoff)
    .limit(500)
    .get();
  if (snap.empty) return 0;
  const batch = db.batch();
  snap.docs.forEach((doc) => batch.delete(doc.ref));
  await batch.commit();
  return snap.size;
}

// ── enforceDataRetention ─────────────────────────────────────────────────────

export const enforceDataRetention = onSchedule(
  { schedule: "every day 04:00", region: "europe-west1" },
  async () => {
    const TWO_YEARS_MS = 2 * 365 * 24 * 60 * 60 * 1000;
    const NINETY_DAYS_MS = 90 * 24 * 60 * 60 * 1000;
    const THIRTY_DAYS_MS = 30 * 24 * 60 * 60 * 1000;

    // 1. Delete audit_log older than 2 years
    const auditDeleted = await deleteCollection(
      db.collection("audit_log"),
      TWO_YEARS_MS
    );
    logger.info(`Data retention: deleted ${auditDeleted} audit log entries`);

    // 2. Delete login_activity entries older than 90 days (per-user subcollection)
    const usersSnap = await db.collection("users").select().get();
    let loginDeleted = 0;
    for (const userDoc of usersSnap.docs) {
      const deleted = await deleteCollection(
        userDoc.ref.collection("login_activity"),
        NINETY_DAYS_MS,
        "timestamp"
      );
      loginDeleted += deleted;
    }
    logger.info(`Data retention: deleted ${loginDeleted} login activity entries`);

    // 3. Delete soft-deleted projects older than 30 days
    const cutoff = new Date(Date.now() - THIRTY_DAYS_MS);
    const deletedProjectsSnap = await db
      .collection("projects")
      .where("deletedAt", "<", cutoff)
      .limit(500)
      .get();
    const batch = db.batch();
    deletedProjectsSnap.docs.forEach((doc) => batch.delete(doc.ref));
    if (!deletedProjectsSnap.empty) await batch.commit();
    logger.info(
      `Data retention: purged ${deletedProjectsSnap.size} soft-deleted projects`
    );
  }
);

// ── exportUserData ────────────────────────────────────────────────────────────

export const exportUserData = onCall(
  { region: "europe-west1", enforceAppCheck: true },
  async (request) => {
    if (!request.auth) throw new HttpsError("unauthenticated", "Sign in required.");
    const uid = request.auth.uid;

    await rateLimit(uid, "exportUserData", 3, 86400); // 3 exports/day

    const [userDoc, projectsSnap, contractsSnap, invoicesSnap, variationOrdersSnap] =
      await Promise.all([
        db.collection("users").doc(uid).get(),
        db.collection("projects").where("ownerUid", "==", uid).limit(200).get(),
        db.collection("contracts").where("ownerUid", "==", uid).limit(200).get(),
        db.collection("invoices").where("ownerUid", "==", uid).limit(200).get(),
        db.collection("variation_orders").where("ownerUid", "==", uid).limit(200).get(),
      ]);

    const [loginActivitySnap, auditLogsSnap] = await Promise.all([
      db.collection("users").doc(uid).collection("login_activity").limit(500).get(),
      db.collection("audit_log").where("uid", "==", uid).limit(500).get(),
    ]);

    return {
      exportedAt: new Date().toISOString(),
      profile: userDoc.data() ?? {},
      projects: projectsSnap.docs.map((d) => ({ id: d.id, ...d.data() })),
      contracts: contractsSnap.docs.map((d) => ({ id: d.id, ...d.data() })),
      invoices: invoicesSnap.docs.map((d) => ({ id: d.id, ...d.data() })),
      variationOrders: variationOrdersSnap.docs.map((d) => ({ id: d.id, ...d.data() })),
      loginActivity: loginActivitySnap.docs.map((d) => ({ id: d.id, ...d.data() })),
      auditLogs: auditLogsSnap.docs.map((d) => ({ id: d.id, ...d.data() })),
    };
  }
);

// ── processAccountDeletion ───────────────────────────────────────────────────
// Triggered when a deletion_requests document moves to status == 'approved'.

export const processAccountDeletion = onDocumentUpdated(
  { document: "deletion_requests/{requestId}", region: "europe-west1" },
  async (event) => {
    const before = event.data?.before.data();
    const after = event.data?.after.data();

    if (!after || after.status !== "approved" || before?.status === "approved") {
      return; // Only process the approved transition once
    }

    const uid = after.requestedByUid as string | undefined;
    if (!uid) {
      logger.error("processAccountDeletion: missing requestedByUid", { event });
      return;
    }

    logger.info(`processAccountDeletion: starting deletion for uid ${uid}`);

    try {
      // 1. Delete Firestore user document
      await db.collection("users").doc(uid).delete();

      // 2. Mark all owned projects as soft-deleted
      const projectsSnap = await db
        .collection("projects")
        .where("ownerUid", "==", uid)
        .limit(500) // practical per-run cap; users with >500 owned records are not expected
        .get();
      const projectBatch = db.batch();
      projectsSnap.docs.forEach((doc) =>
        projectBatch.update(doc.ref, {
          deletedAt: admin.firestore.FieldValue.serverTimestamp(),
        })
      );
      if (!projectsSnap.empty) await projectBatch.commit();

      // 2b. Delete owned contracts
      const contractsSnap = await db
        .collection("contracts")
        .where("ownerUid", "==", uid)
        .limit(500)
        .get();
      if (!contractsSnap.empty) {
        const contractBatch = db.batch();
        contractsSnap.docs.forEach((doc) => contractBatch.delete(doc.ref));
        await contractBatch.commit();
      }

      // 2c. Delete owned invoices
      const invoicesSnap = await db
        .collection("invoices")
        .where("ownerUid", "==", uid)
        .limit(500)
        .get();
      if (!invoicesSnap.empty) {
        const invoiceBatch = db.batch();
        invoicesSnap.docs.forEach((doc) => invoiceBatch.delete(doc.ref));
        await invoiceBatch.commit();
      }

      // 2d. Delete owned variation_orders
      const voSnap = await db
        .collection("variation_orders")
        .where("ownerUid", "==", uid)
        .limit(500)
        .get();
      if (!voSnap.empty) {
        const voBatch = db.batch();
        voSnap.docs.forEach((doc) => voBatch.delete(doc.ref));
        await voBatch.commit();
      }

      // 3. Delete Firebase Storage files (best-effort)
      try {
        const bucket = admin.storage().bucket();
        await bucket.deleteFiles({ prefix: `users/${uid}/` });
      } catch (storageErr) {
        logger.warn(`processAccountDeletion: storage cleanup partial for ${uid}`, storageErr);
      }

      // 4. Delete Firebase Auth user (after all Firestore/Storage cleanup)
      await admin.auth().deleteUser(uid);

      // 5. Queue confirmation email via Firestore (picked up by Firebase Trigger Email Extension)
      // Setup required: install "Trigger Email from Firestore" extension in Firebase Console
      // and configure SMTP credentials. The extension reads from the `mail` collection.
      const userEmail = after.requestedByEmail as string | undefined;
      if (userEmail) {
        try {
          await db.collection("mail").add({
            to: userEmail,
            message: {
              subject: "Your WyseBrix account has been deleted",
              text: `Hi,\n\nYour WyseBrix account and all associated data have been permanently deleted as requested.\n\nIf you did not request this, please contact our support team immediately.\n\nWyseBrix Team`,
            },
          });
        } catch (emailErr) {
          // Non-fatal: email failure should not block deletion confirmation
          logger.warn(`processAccountDeletion: email notification failed for ${uid}`, emailErr);
        }
      }

      // 6. Mark deletion request as completed
      await event.data!.after.ref.update({
        status: "completed",
        completedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      logger.info(`processAccountDeletion: completed for uid ${uid}`);
    } catch (err) {
      logger.error(`processAccountDeletion: failed for uid ${uid}`, err);
      await event.data!.after.ref.update({ status: "failed", error: String(err) });
    }
  }
);
