import * as admin from "firebase-admin";
import * as crypto from "crypto";
import { logger } from "firebase-functions";
import { onCall, onRequest, HttpsError } from "firebase-functions/v2/https";
import { defineSecret } from "firebase-functions/params";
import {
  onDocumentCreated,
  onDocumentDeleted,
  onDocumentUpdated,
  onDocumentWritten,
} from "firebase-functions/v2/firestore";
import { onSchedule } from "firebase-functions/v2/scheduler";
import { BigQuery } from "@google-cloud/bigquery";

// Firebase Secret Manager — set with:
//   firebase functions:secrets:set PAYSTACK_SECRET_KEY
//   firebase functions:secrets:set STRIPE_SECRET_KEY
// Then deploy: cd functions && npm run build && firebase deploy --only functions
const paystackSecretKey = defineSecret("PAYSTACK_SECRET_KEY");
const stripeSecretKey = defineSecret("STRIPE_SECRET_KEY");

// Initialize Admin SDK once
if (admin.apps.length === 0) {
  admin.initializeApp();
}

const db = admin.firestore();

// ── Idempotency helper ───────────────────────────────────────────────────────
// Writes a sentinel doc to _processed/{eventId} to prevent double-processing
// of the same Firestore trigger event. Returns true if the event was already
// processed (caller should return early).
async function dedupeEvent(eventId: string): Promise<boolean> {
  const ref = db.doc(`_processed/${eventId}`);
  const snap = await ref.get();
  if (snap.exists) return true;
  await ref.set({ ts: admin.firestore.FieldValue.serverTimestamp() });
  return false;
}

// ── Notification helpers ────────────────────────────────────────────────────

// Maps notification type → notificationPrefs key stored on users/{uid}.
// If the key is missing from prefs, the default is enabled (true).
const notifTypeToPrefKey: Record<string, string> = {
  update_new:                 "project_updates",
  phase_new:                  "phase_changes",
  cost_new:                   "cost_entries",
  deletion_new:               "deletion_requests",
  deletion_approved:          "deletion_requests",
  deletion_denied:            "deletion_requests",
  contract_new:               "contracts",
  contract_signed:            "contracts",
  assignment:                 "assignment",
  variation_order_new:        "change_orders",
  variation_order_approved:   "change_orders",
  variation_order_rejected:   "change_orders",
  site_visit_new:             "site_inspections",
  snag_new:                   "snag_list",
  issue_report:               "issue_reports",
  safety_incident:            "safety_incidents",
  rfq_received:               "quote_responses",
  rfq_responded:              "quote_responses",
  rfq_accepted:               "quote_responses",
  rfq_declined:               "quote_responses",
  chat_message:               "chat_messages",
  budget_alert:               "budget_alerts",
  task_comment:               "task_comments",
  chat_mention:               "chat_messages",
};

async function sendToUser(
  uid: string,
  title: string,
  body: string,
  data: Record<string, string>,
  notifType?: string,
): Promise<void> {
  // Always persist to Firestore inbox (even if no FCM token or push disabled)
  await db.collection("users").doc(uid).collection("notifications").add({
    title,
    body,
    data,
    read: false,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  const snap = await db.collection("users").doc(uid).get();
  const userData = snap.data() ?? {};
  const token = userData.fcmToken as string | undefined;
  if (!token) return;

  // Check per-type preference (default = enabled when key absent)
  if (notifType) {
    const prefKey = notifTypeToPrefKey[notifType];
    if (prefKey) {
      const prefs = userData.notificationPrefs as Record<string, boolean> | undefined;
      const enabled = prefs?.[prefKey] ?? true;
      if (!enabled) return; // user opted out of this type
    }
  }

  await admin.messaging().send({
    token,
    notification: { title, body },
    data,
    android: { priority: "high" },
    apns: { payload: { aps: { sound: "default" } } },
  });
}

async function getProject(projectId: string) {
  const doc = await db.collection("projects").doc(projectId).get();
  const d = doc.data() ?? {};
  return { ownerUid: d.ownerUid as string, title: d.title as string };
}

// ── Priority 3: Sync role → Custom Claims ───────────────────────────────────
// Whenever a users/{uid} document is written, read the `role` field and set
// matching custom claims so Firestore rules can use request.auth.token.role
// instead of performing a Firestore document read inside the rule.
//
// GCP Note: After role promotion, the client must call getIdToken(true) to
// force-refresh and pick up new claims before they take effect. The Flutter
// auth_service.dart does this automatically after signIn.
export const onUserRoleChange = onDocumentWritten(
  "users/{uid}",
  async (event) => {
    const uid = event.params.uid;
    const newData = event.data?.after?.data();
    if (!newData) return; // document deleted — no claims to set

    const role = newData.role as string | undefined;
    if (!role) return;

    try {
      const tier = (newData.subscriptionTier as string | undefined) ?? "free";
      const passExpiry = newData.projectPassExpiresAt
        ? (newData.projectPassExpiresAt as admin.firestore.Timestamp).toDate().getTime()
        : null;
      await admin.auth().setCustomUserClaims(uid, {
        role,
        admin: role === "admin",
        subscriptionTier: tier,
        projectPassExpiresAt: passExpiry,
      });
      logger.info("onUserRoleChange: custom claims set", { uid, role, tier });
    } catch (e: unknown) {
      const err = e as Error;
      logger.error("onUserRoleChange: setCustomUserClaims failed", {
        functionName: "onUserRoleChange",
        uid,
        error: err.message,
        stack: err.stack,
      });
    }
  },
);

// ── setUserRoles callable ────────────────────────────────────────────────────
export const setUserRoles = onCall({ enforceAppCheck: false }, async (request) => {
  const caller = request.auth;
  if (!caller?.token?.admin) {
    throw new Error("permission-denied: Only admins can set roles.");
  }

  const { uid, roles } = request.data || {};
  if (typeof uid !== "string" || !uid) {
    throw new Error("invalid-argument: 'uid' is required.");
  }
  if (typeof roles !== "object" || roles == null) {
    throw new Error("invalid-argument: 'roles' must be an object.");
  }

  const allowedKeys = ["basic", "vendor", "architect", "builder", "admin"] as const;
  const claims: Record<string, boolean> = {};
  for (const key of allowedKeys) {
    if (roles[key] != null) claims[key] = !!roles[key];
  }

  await admin.auth().setCustomUserClaims(uid, {
    ...claims,
    role: claims.admin
      ? "admin"
      : claims.vendor
        ? "vendor"
        : claims.architect
          ? "architect"
          : claims.builder
            ? "builder"
            : "basic",
  });

  await db.collection("users").doc(uid).set(
    {
      uid,
      roles: claims,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    { merge: true },
  );

  return { ok: true, uid, roles: claims };
});

// ── Paystack transaction initialisation ─────────────────────────────────────
// Called from PaystackService.initTransaction() in the Flutter app.
// Never exposes the secret key to the client.
//
// Setup:
//   firebase functions:secrets:set PAYSTACK_SECRET_KEY
//   (Enter your Paystack secret key — sk_test_... or sk_live_...)
//   firebase deploy --only functions
//
// The Flutter app reads the *public* key from AppConfig.paystackPublicKey
// (passed via --dart-define=PAYSTACK_PUBLIC_KEY=pk_live_...).
export const initPaystackTransaction = onCall(
  { secrets: [paystackSecretKey] },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "You must be signed in.");
    }

    const { amountPesewas, email, reference, metadata } = request.data ?? {};

    if (typeof amountPesewas !== "number" || amountPesewas <= 0) {
      throw new HttpsError("invalid-argument", "'amountPesewas' must be a positive number.");
    }
    if (typeof email !== "string" || !email.includes("@")) {
      throw new HttpsError("invalid-argument", "'email' must be a valid email address.");
    }
    if (typeof reference !== "string" || !reference) {
      throw new HttpsError("invalid-argument", "'reference' must be a non-empty string.");
    }

    const secretKey = paystackSecretKey.value();
    if (!secretKey) {
      logger.error("initPaystackTransaction: PAYSTACK_SECRET_KEY secret is not set.");
      throw new HttpsError("internal", "Payment configuration error.");
    }

    try {
      const response = await fetch("https://api.paystack.co/transaction/initialize", {
        method: "POST",
        headers: {
          Authorization: `Bearer ${secretKey}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          amount: amountPesewas,
          email,
          reference,
          metadata: metadata ?? {},
          currency: "GHS",
        }),
      });

      const json = (await response.json()) as {
        status: boolean;
        message: string;
        data?: { authorization_url: string; reference: string };
      };

      if (!json.status || !json.data) {
        logger.error("initPaystackTransaction: Paystack returned error", { message: json.message });
        throw new HttpsError("internal", `Paystack error: ${json.message}`);
      }

      logger.info("initPaystackTransaction: transaction initialised", {
        uid: request.auth.uid,
        reference: json.data.reference,
      });

      return {
        authorizationUrl: json.data.authorization_url,
        reference: json.data.reference,
      };
    } catch (e: unknown) {
      if (e instanceof HttpsError) throw e;
      const err = e as Error;
      logger.error("initPaystackTransaction: fetch failed", {
        error: err.message,
        stack: err.stack,
      });
      throw new HttpsError("internal", "Failed to contact payment provider.");
    }
  },
);

// ── Priority 7: Firestore triggers with structured logging + try/catch ───────
// All trigger handlers:
//  • Wrapped in try/catch — errors logged as severity=ERROR to Cloud Logging.
//  • Use logger.info/error (structured JSON) instead of console.log/error.
//  • onDocumentCreated triggers use dedupeEvent() to prevent double-processing.
//
// GCP Alert: Set up a Log-based Alert in GCP Console for:
//   resource.type="cloud_function" AND severity=ERROR
// to receive notifications on any failed trigger.

// 1. Phase added → notify owner
export const onPhaseCreated = onDocumentCreated(
  "projects/{projectId}/phases/{phaseId}",
  async (event) => {
    if (await dedupeEvent(event.id)) return;
    try {
      const { projectId } = event.params;
      const phase = event.data?.data() ?? {};
      const { ownerUid, title } = await getProject(projectId);
      await sendToUser(
        ownerUid,
        "Phase Added",
        `Builder added phase '${phase.name ?? ""}' to ${title}`,
        { type: "phase_new", projectId },
        "phase_new",
      );
      logger.info("onPhaseCreated: notification sent", { projectId });
    } catch (e: unknown) {
      const err = e as Error;
      logger.error("onPhaseCreated failed", {
        functionName: "onPhaseCreated",
        eventId: event.id,
        error: err.message,
        stack: err.stack,
      });
    }
  },
);

// 2. Cost entry → notify owner + check budget overrun
export const onCostCreated = onDocumentCreated(
  "projects/{projectId}/costs/{costId}",
  async (event) => {
    if (await dedupeEvent(event.id)) return;
    try {
      const { projectId } = event.params;
      const cost = event.data?.data() ?? {};
      const projectDoc = await db.collection("projects").doc(projectId).get();
      const projectData = projectDoc.data() ?? {};
      const ownerUid = projectData.ownerUid as string;
      const title = (projectData.title as string) ?? "your project";
      const amt = (cost.amountGhs as number ?? 0).toLocaleString("en-GH", {
        maximumFractionDigits: 0,
      });
      await sendToUser(
        ownerUid,
        "New Cost Entry",
        `Builder recorded ₵${amt} for ${cost.category ?? "costs"} on ${title}`,
        { type: "cost_new", projectId },
        "cost_new",
      );

      // Budget overrun check
      const budget = (projectData.budget as number) ?? 0;
      const amountSpent = (projectData.amountSpent as number) ?? 0;
      const threshold = (projectData.budgetAlertThreshold as number) ?? 80;
      if (budget > 0 && amountSpent > 0 && threshold > 0) {
        const pct = (amountSpent / budget) * 100;
        if (pct >= threshold) {
          const spentFmt = amountSpent.toLocaleString("en-GH", { maximumFractionDigits: 0 });
          const budgetFmt = budget.toLocaleString("en-GH", { maximumFractionDigits: 0 });
          await sendToUser(
            ownerUid,
            "Budget Alert",
            `${title} has used ${pct.toFixed(0)}% of budget (₵${spentFmt} / ₵${budgetFmt})`,
            { type: "budget_alert", projectId },
            "budget_alert",
          );
        }
      }

      logger.info("onCostCreated: notification sent", { projectId });
    } catch (e: unknown) {
      const err = e as Error;
      logger.error("onCostCreated failed", {
        functionName: "onCostCreated",
        eventId: event.id,
        error: err.message,
        stack: err.stack,
      });
    }
  },
);

// 3. Update posted → notify owner
export const onUpdateCreated = onDocumentCreated(
  "projects/{projectId}/updates/{updateId}",
  async (event) => {
    if (await dedupeEvent(event.id)) return;
    try {
      const { projectId } = event.params;
      const { ownerUid, title } = await getProject(projectId);
      await sendToUser(
        ownerUid,
        "Project Update",
        `Builder posted an update on ${title}`,
        { type: "update_new", projectId },
        "update_new",
      );
      logger.info("onUpdateCreated: notification sent", { projectId });
    } catch (e: unknown) {
      const err = e as Error;
      logger.error("onUpdateCreated failed", {
        functionName: "onUpdateCreated",
        eventId: event.id,
        error: err.message,
        stack: err.stack,
      });
    }
  },
);

// 4. Deletion request → notify owner
export const onDeletionRequestCreated = onDocumentCreated(
  "projects/{projectId}/deletionRequests/{reqId}",
  async (event) => {
    if (await dedupeEvent(event.id)) return;
    try {
      const { projectId } = event.params;
      const req = event.data?.data() ?? {};
      const { ownerUid, title } = await getProject(projectId);
      await sendToUser(
        ownerUid,
        "Deletion Request",
        `Builder wants to delete a ${req.itemType ?? "item"} on ${title}`,
        { type: "deletion_new", projectId },
        "deletion_new",
      );
      logger.info("onDeletionRequestCreated: notification sent", { projectId });
    } catch (e: unknown) {
      const err = e as Error;
      logger.error("onDeletionRequestCreated failed", {
        functionName: "onDeletionRequestCreated",
        eventId: event.id,
        error: err.message,
        stack: err.stack,
      });
    }
  },
);

// 5. Deletion request resolved → notify builder
export const onDeletionRequestUpdated = onDocumentUpdated(
  "projects/{projectId}/deletionRequests/{reqId}",
  async (event) => {
    try {
      const { projectId } = event.params;
      const before = event.data?.before.data() ?? {};
      const after = event.data?.after.data() ?? {};
      if (before.status === after.status) return;
      const builderUid = after.requestedByUid as string;
      const { title } = await getProject(projectId);
      if (after.status === "approved") {
        await sendToUser(
          builderUid,
          "Request Approved",
          `Your deletion request was approved on ${title}`,
          { type: "deletion_approved", projectId },
          "deletion_approved",
        );
      } else if (after.status === "denied") {
        await sendToUser(
          builderUid,
          "Request Denied",
          `Your deletion request was denied on ${title}`,
          { type: "deletion_denied", projectId },
          "deletion_denied",
        );
      }
      logger.info("onDeletionRequestUpdated: notification sent", { projectId });
    } catch (e: unknown) {
      const err = e as Error;
      logger.error("onDeletionRequestUpdated failed", {
        functionName: "onDeletionRequestUpdated",
        eventId: event.id,
        error: err.message,
        stack: err.stack,
      });
    }
  },
);

// 6. Contract created → notify builder
export const onContractCreated = onDocumentCreated(
  "contracts/{contractId}",
  async (event) => {
    if (await dedupeEvent(event.id)) return;
    try {
      const contract = event.data?.data() ?? {};
      const builderUid = contract.builderUid as string;
      const ownerName = (contract.ownerName as string) ?? "An owner";
      const projectId = (contract.projectId as string) ?? "";
      const projectTitle = (contract.projectTitle as string) ?? "your project";
      await sendToUser(
        builderUid,
        "New Contract",
        `${ownerName} sent you a contract for ${projectTitle}`,
        { type: "contract_new", projectId },
        "contract_new",
      );
      logger.info("onContractCreated: notification sent", { contractId: event.params.contractId });
    } catch (e: unknown) {
      const err = e as Error;
      logger.error("onContractCreated failed", {
        functionName: "onContractCreated",
        eventId: event.id,
        error: err.message,
        stack: err.stack,
      });
    }
  },
);

// 7. Contract signed → notify owner
export const onContractUpdated = onDocumentUpdated(
  "contracts/{contractId}",
  async (event) => {
    try {
      const before = event.data?.before.data() ?? {};
      const after = event.data?.after.data() ?? {};
      if (before.status === after.status) return;
      if (after.status !== "active") return;
      const ownerUid = after.ownerUid as string;
      const projectId = (after.projectId as string) ?? "";
      const projectTitle = (after.projectTitle as string) ?? "your project";
      await sendToUser(
        ownerUid,
        "Contract Signed",
        `Your builder signed the contract for ${projectTitle}`,
        { type: "contract_signed", projectId },
        "contract_signed",
      );
      logger.info("onContractUpdated: contract signed notification sent", {
        contractId: event.params.contractId,
      });
    } catch (e: unknown) {
      const err = e as Error;
      logger.error("onContractUpdated failed", {
        functionName: "onContractUpdated",
        eventId: event.id,
        error: err.message,
        stack: err.stack,
      });
    }
  },
);

// 8. Builder assigned to project → notify builder
export const onProjectUpdated = onDocumentUpdated(
  "projects/{projectId}",
  async (event) => {
    try {
      const { projectId } = event.params;
      const before = event.data?.before.data() ?? {};
      const after = event.data?.after.data() ?? {};
      const prev = before.assignedPmUid as string | undefined;
      const curr = after.assignedPmUid as string | undefined;
      if (!curr || curr === prev) return;
      await sendToUser(
        curr,
        "Project Assignment",
        `You've been assigned to ${(after.title as string) ?? "a project"}`,
        { type: "assignment", projectId },
        "assignment",
      );
      logger.info("onProjectUpdated: assignment notification sent", { projectId });
    } catch (e: unknown) {
      const err = e as Error;
      logger.error("onProjectUpdated failed", {
        functionName: "onProjectUpdated",
        eventId: event.id,
        error: err.message,
        stack: err.stack,
      });
    }
  },
);

// 9. Variation order submitted → notify owner
export const onVariationOrderCreated = onDocumentCreated(
  "projects/{projectId}/variation_orders/{voId}",
  async (event) => {
    if (await dedupeEvent(event.id)) return;
    try {
      const { projectId } = event.params;
      const vo = event.data?.data() ?? {};
      const { ownerUid, title } = await getProject(projectId);
      const delta = (vo.costDeltaGhs as number ?? 0);
      const sign = delta >= 0 ? "+" : "";
      const amt = `${sign}₵${Math.abs(delta).toLocaleString("en-GH", { maximumFractionDigits: 0 })}`;
      await sendToUser(
        ownerUid,
        "Change Order Submitted",
        `Builder submitted a change order '${vo.title ?? ""}' (${amt}) on ${title}`,
        { type: "variation_order_new", projectId },
        "variation_order_new",
      );
      logger.info("onVariationOrderCreated: notification sent", { projectId });
    } catch (e: unknown) {
      const err = e as Error;
      logger.error("onVariationOrderCreated failed", {
        functionName: "onVariationOrderCreated",
        eventId: event.id,
        error: err.message,
        stack: err.stack,
      });
    }
  },
);

// 10. Variation order decided → notify builder
export const onVariationOrderUpdated = onDocumentUpdated(
  "projects/{projectId}/variation_orders/{voId}",
  async (event) => {
    try {
      const { projectId } = event.params;
      const before = event.data?.before.data() ?? {};
      const after = event.data?.after.data() ?? {};
      if (before.status === after.status) return;
      const builderUid = after.submittedByUid as string;
      const { title } = await getProject(projectId);
      const approved = after.status === "approved";
      await sendToUser(
        builderUid,
        approved ? "Change Order Approved" : "Change Order Rejected",
        approved
          ? `Your change order '${after.title ?? ""}' was approved on ${title}`
          : `Your change order '${after.title ?? ""}' was rejected on ${title}`,
        { type: approved ? "variation_order_approved" : "variation_order_rejected", projectId },
        approved ? "variation_order_approved" : "variation_order_rejected",
      );
      logger.info("onVariationOrderUpdated: notification sent", { projectId });
    } catch (e: unknown) {
      const err = e as Error;
      logger.error("onVariationOrderUpdated failed", {
        functionName: "onVariationOrderUpdated",
        eventId: event.id,
        error: err.message,
        stack: err.stack,
      });
    }
  },
);

// 11. Site visit scheduled → notify project members
export const onSiteVisitCreated = onDocumentCreated(
  "projects/{projectId}/site_visits/{visitId}",
  async (event) => {
    if (await dedupeEvent(event.id)) return;
    try {
      const { projectId } = event.params;
      const visit = event.data?.data() ?? {};
      const projectDoc = await db.collection("projects").doc(projectId).get();
      const projectData = projectDoc.data() ?? {};
      const ownerUid = projectData.ownerUid as string;
      const assignedPmUid = projectData.assignedPmUid as string | undefined;
      const title = projectData.title as string ?? "your project";
      const schedulerUid = visit.scheduledByUid as string;

      // Notify owner (unless they scheduled it themselves)
      if (ownerUid && ownerUid !== schedulerUid) {
        await sendToUser(
          ownerUid,
          "Site Inspection Scheduled",
          `${visit.scheduledByName ?? "Someone"} scheduled a site visit for ${title}`,
          { type: "site_visit_new", projectId },
          "site_visit_new",
        );
      }
      // Notify builder (unless they scheduled it themselves)
      if (assignedPmUid && assignedPmUid !== schedulerUid) {
        await sendToUser(
          assignedPmUid,
          "Site Inspection Scheduled",
          `A site visit has been scheduled for ${title}`,
          { type: "site_visit_new", projectId },
          "site_visit_new",
        );
      }
      logger.info("onSiteVisitCreated: notifications sent", { projectId });
    } catch (e: unknown) {
      const err = e as Error;
      logger.error("onSiteVisitCreated failed", {
        functionName: "onSiteVisitCreated",
        eventId: event.id,
        error: err.message,
        stack: err.stack,
      });
    }
  },
);

// 12. Snag item raised → notify project owner (type-aware)
export const onSnagItemCreated = onDocumentCreated(
  "projects/{projectId}/snag_items/{snagId}",
  async (event) => {
    if (await dedupeEvent(event.id)) return;
    try {
      const { projectId } = event.params;
      const snag = event.data?.data() ?? {};
      const { ownerUid, title } = await getProject(projectId);
      const issueType = snag.issueType as string | undefined;
      const description = snag.description as string | undefined ?? "";

      if (issueType === "safetyIncident") {
        // Safety incidents bypass issue_reports pref — always notified
        await sendToUser(
          ownerUid,
          "🚨 Safety Incident Reported",
          `A safety incident was reported on ${title}: ${description}`,
          { type: "safety_incident", projectId },
          // Pass undefined-equivalent: use a type that bypasses pref lookup
          undefined,
        );
      } else {
        const notifTitle =
          issueType === "qualityIssue"
            ? "Quality Issue Reported"
            : "Issue Reported";
        await sendToUser(
          ownerUid,
          notifTitle,
          `A new issue was reported on ${title}: ${description}`,
          { type: "issue_report", projectId },
          "issue_report",
        );
      }
      logger.info("onSnagItemCreated: notification sent", { projectId, issueType });
    } catch (e: unknown) {
      const err = e as Error;
      logger.error("onSnagItemCreated failed", {
        functionName: "onSnagItemCreated",
        eventId: event.id,
        error: err.message,
        stack: err.stack,
      });
    }
  },
);

// ── Priority 8: BigQuery daily project summary rollup ───────────────────────
// Prerequisites:
//  1. Enable the "Firestore → BigQuery" extension in Firebase Console to
//     stream `projects`, `projects/{id}/costs`, and `rfq_requests` collections
//     into BigQuery dataset `wysebrix_analytics` automatically.
//  2. Run `npm install` in functions/ after adding @google-cloud/bigquery
//     to package.json dependencies.
//  3. Grant the Cloud Functions service account BigQuery Data Editor role.
//
// BigQuery schema for project_summary table (auto-created on first write):
//   ownerUid STRING, totalProjects INTEGER, totalBudgetGhs FLOAT,
//   totalSpentGhs FLOAT, reportDate DATE, updatedAt TIMESTAMP
//
// This function runs daily at 02:00 UTC and writes per-owner aggregate stats.
export const dailyProjectRollup = onSchedule("0 2 * * *", async () => {
  try {
    const bq = new BigQuery();
    const dataset = bq.dataset("wysebrix_analytics");
    const table = dataset.table("project_summary");

    // Aggregate from Firestore
    const snap = await db.collection("projects").get();
    const rollup: Record<string, { totalProjects: number; totalBudget: number; totalSpent: number }> = {};

    for (const doc of snap.docs) {
      const d = doc.data();
      const owner = d.ownerUid as string;
      if (!owner) continue;
      if (!rollup[owner]) {
        rollup[owner] = { totalProjects: 0, totalBudget: 0, totalSpent: 0 };
      }
      rollup[owner].totalProjects += 1;
      rollup[owner].totalBudget += (d.budget as number) ?? 0;
      rollup[owner].totalSpent += (d.amountSpent as number) ?? 0;
    }

    const today = new Date().toISOString().split("T")[0];
    const rows = Object.entries(rollup).map(([ownerUid, stats]) => ({
      ownerUid,
      totalProjects: stats.totalProjects,
      totalBudgetGhs: stats.totalBudget,
      totalSpentGhs: stats.totalSpent,
      reportDate: today,
      updatedAt: new Date().toISOString(),
    }));

    if (rows.length > 0) {
      await table.insert(rows);
      logger.info("dailyProjectRollup: inserted rows", { count: rows.length, date: today });
    } else {
      logger.info("dailyProjectRollup: no projects found, skipping insert");
    }
  } catch (e: unknown) {
    const err = e as Error;
    logger.error("dailyProjectRollup failed", {
      functionName: "dailyProjectRollup",
      error: err.message,
      stack: err.stack,
    });
  }
});

// ── Daily amountSpent + phase actualCostGhs reconciliation ──────────────────
// Corrects drift caused by offline-queue failures or concurrent writes.
// Runs daily at 03:00 UTC, well after the dailyProjectRollup at 02:00 UTC.
export const reconcileAmountSpent = onSchedule("0 3 * * *", async () => {
  try {
    const projectsSnap = await db.collection("projects").get();
    let fixedProjects = 0;
    let fixedPhases = 0;

    for (const projectDoc of projectsSnap.docs) {
      const costsSnap = await db
        .collection("projects").doc(projectDoc.id)
        .collection("costs").get();

      // Project amountSpent
      const actualSpent = costsSnap.docs.reduce(
        (sum, d) => sum + ((d.data().amountGhs as number) ?? 0),
        0,
      );
      if (Math.abs(actualSpent - ((projectDoc.data().amountSpent as number) ?? 0)) > 0.01) {
        await projectDoc.ref.update({ amountSpent: actualSpent });
        fixedProjects++;
      }

      // Phase actualCostGhs
      const phasesSnap = await db
        .collection("projects").doc(projectDoc.id)
        .collection("phases").get();
      for (const phaseDoc of phasesSnap.docs) {
        const phaseActual = costsSnap.docs
          .filter((c) => c.data().phaseId === phaseDoc.id)
          .reduce((sum, d) => sum + ((d.data().amountGhs as number) ?? 0), 0);
        if (Math.abs(phaseActual - ((phaseDoc.data().actualCostGhs as number) ?? 0)) > 0.01) {
          await phaseDoc.ref.update({ actualCostGhs: phaseActual });
          fixedPhases++;
        }
      }
    }

    logger.info(
      `reconcileAmountSpent: ${projectsSnap.size} projects checked, ` +
      `${fixedProjects} project totals fixed, ${fixedPhases} phase totals fixed`,
    );
  } catch (e: unknown) {
    const err = e as Error;
    logger.error("reconcileAmountSpent failed", {
      functionName: "reconcileAmountSpent",
      error: err.message,
      stack: err.stack,
    });
  }
});

// 13. RFQ request created → notify vendor
export const onRfqCreated = onDocumentCreated(
  "rfq_requests/{rfqId}",
  async (event) => {
    if (await dedupeEvent(event.id)) return;
    try {
      const rfq = event.data?.data() ?? {};
      const vendorId = rfq.vendorId as string;
      const projectTitle = (rfq.projectTitle as string) ?? "a project";
      const ownerName = (rfq.ownerName as string) ?? "An owner";
      if (!vendorId) return;
      await sendToUser(
        vendorId,
        "Quote Request Received",
        `${ownerName} sent you a quote request for ${projectTitle}`,
        { type: "rfq_received", projectId: (rfq.projectId as string) ?? "" },
        "rfq_received",
      );
      logger.info("onRfqCreated: notification sent", { rfqId: event.params.rfqId });
    } catch (e: unknown) {
      const err = e as Error;
      logger.error("onRfqCreated failed", {
        functionName: "onRfqCreated",
        eventId: event.id,
        error: err.message,
        stack: err.stack,
      });
    }
  },
);

// 14. RFQ status changed → notify owner (responded/accepted/declined)
export const onRfqUpdated = onDocumentUpdated(
  "rfq_requests/{rfqId}",
  async (event) => {
    try {
      const before = event.data?.before.data() ?? {};
      const after = event.data?.after.data() ?? {};
      if (before.status === after.status) return;

      const ownerUid = after.ownerUid as string;
      const projectTitle = (after.projectTitle as string) ?? "your project";
      const projectId = (after.projectId as string) ?? "";
      const newStatus = after.status as string;

      let title = "";
      let body = "";
      let type = "";

      if (newStatus === "responded") {
        title = "Vendor Quote Received";
        body = `A vendor has submitted a quote for ${projectTitle}`;
        type = "rfq_responded";
      } else if (newStatus === "accepted") {
        // Notify the vendor their quote was accepted
        const vendorId = after.vendorId as string;
        if (vendorId) {
          await sendToUser(
            vendorId,
            "Quote Accepted",
            `Your quote for ${projectTitle} was accepted`,
            { type: "rfq_accepted", projectId },
            "rfq_accepted",
          );
        }
        return;
      } else if (newStatus === "declined") {
        const vendorId = after.vendorId as string;
        if (vendorId) {
          await sendToUser(
            vendorId,
            "Quote Declined",
            `Your quote for ${projectTitle} was declined`,
            { type: "rfq_declined", projectId },
            "rfq_declined",
          );
        }
        return;
      } else {
        return;
      }

      if (ownerUid) {
        await sendToUser(
          ownerUid,
          title,
          body,
          { type, projectId },
          type,
        );
      }
      logger.info("onRfqUpdated: notification sent", { rfqId: event.params.rfqId, status: newStatus });
    } catch (e: unknown) {
      const err = e as Error;
      logger.error("onRfqUpdated failed", {
        functionName: "onRfqUpdated",
        eventId: event.id,
        error: err.message,
        stack: err.stack,
      });
    }
  },
);

// 16. Project deleted → cascade-delete all sub-collections
export const onProjectDeleted = onDocumentDeleted(
  "projects/{projectId}",
  async (event) => {
    const projectId = event.params.projectId;
    try {
      await db.recursiveDelete(db.collection("projects").doc(projectId));
      logger.info(`onProjectDeleted: cascade-deleted sub-collections for project ${projectId}`);
    } catch (e: unknown) {
      const err = e as Error;
      logger.error("onProjectDeleted failed", {
        functionName: "onProjectDeleted",
        projectId,
        error: err.message,
        stack: err.stack,
      });
    }
  },
);

// 15. Chat message sent → notify ALL project members (including teamMemberUids)
// Also handles @mention notifications (bypass chat pref for mentioned users).
export const onChatMessageCreated = onDocumentCreated(
  "projects/{projectId}/chat/{messageId}",
  async (event) => {
    if (await dedupeEvent(event.id)) return;
    try {
      const { projectId } = event.params;
      const msg = event.data?.data() ?? {};
      const senderUid = msg.senderUid as string;
      const senderName = (msg.senderName as string) ?? "Someone";
      const text = (msg.text as string) ?? "";
      const preview = text.length > 60 ? `${text.substring(0, 60)}…` : text;
      const mentionedUids = (msg.mentions as string[]) ?? [];

      const projectDoc = await db.collection("projects").doc(projectId).get();
      const projectData = projectDoc.data() ?? {};
      const ownerUid = projectData.ownerUid as string;
      const assignedPmUid = projectData.assignedPmUid as string | undefined;
      const teamMemberUids = (projectData.teamMemberUids as string[]) ?? [];
      const projectTitle = (projectData.title as string) ?? "your project";

      // All project members (deduplicated, excluding sender)
      const allRecipients = [
        ...new Set([ownerUid, assignedPmUid, ...teamMemberUids]),
      ].filter((uid): uid is string => !!uid && uid !== senderUid);

      for (const uid of allRecipients) {
        // For mentioned users: bypass the chat_messages pref (they always get notified)
        const isMentioned = mentionedUids.includes(uid);
        await sendToUser(
          uid,
          `${senderName} — ${projectTitle}`,
          isMentioned ? `@you: ${preview}` : preview,
          { type: "chat_message", projectId },
          isMentioned ? undefined : "chat_message",
        );
      }

      // Notify mentioned users not already in allRecipients
      const extraMentions = mentionedUids.filter(
        (uid) => uid !== senderUid && !allRecipients.includes(uid),
      );
      for (const uid of extraMentions) {
        await sendToUser(
          uid,
          `${senderName} mentioned you — ${projectTitle}`,
          preview,
          { type: "chat_message", projectId },
          undefined, // bypass pref check for mentions
        );
      }

      logger.info("onChatMessageCreated: notifications sent", {
        projectId,
        recipients: allRecipients.length,
        mentions: mentionedUids.length,
      });
    } catch (e: unknown) {
      const err = e as Error;
      logger.error("onChatMessageCreated failed", {
        functionName: "onChatMessageCreated",
        eventId: event.id,
        error: err.message,
        stack: err.stack,
      });
    }
  },
);

// 17. Task comment created → notify task assignee + project owner
export const onTaskCommentCreated = onDocumentCreated(
  "projects/{projectId}/tasks/{taskId}/comments/{commentId}",
  async (event) => {
    if (await dedupeEvent(event.id)) return;
    try {
      const { projectId, taskId } = event.params;
      const comment = event.data?.data() ?? {};
      const authorUid = comment.authorUid as string;
      const authorName = (comment.authorName as string) ?? "Someone";
      const text = (comment.text as string) ?? "";
      const preview = text.length > 80 ? `${text.substring(0, 80)}…` : text;

      const taskDoc = await db
        .collection("projects").doc(projectId)
        .collection("tasks").doc(taskId)
        .get();
      const taskData = taskDoc.data() ?? {};
      const taskTitle = (taskData.title as string) ?? "a task";
      const assigneeUid = taskData.assigneeUid as string | undefined;

      const projectDoc = await db.collection("projects").doc(projectId).get();
      const projectData = projectDoc.data() ?? {};
      const ownerUid = projectData.ownerUid as string;
      const projectTitle = (projectData.title as string) ?? "your project";

      const recipients = [
        ...new Set([ownerUid, assigneeUid]),
      ].filter((uid): uid is string => !!uid && uid !== authorUid);

      for (const uid of recipients) {
        await sendToUser(
          uid,
          `${authorName} commented on "${taskTitle}"`,
          preview,
          { type: "task_comment", projectId, taskId },
          "task_comment",
        );
      }
      logger.info("onTaskCommentCreated: notifications sent", {
        projectId,
        taskId,
        recipients: recipients.length,
      });
    } catch (e: unknown) {
      const err = e as Error;
      logger.error("onTaskCommentCreated failed", {
        functionName: "onTaskCommentCreated",
        eventId: event.id,
        error: err.message,
        stack: err.stack,
      });
    }
  },
);

// 18. createInvitation callable — creates project invitation token
export const createInvitation = onCall(
  { enforceAppCheck: false },
  async (request) => {
    const caller = request.auth;
    if (!caller) {
      throw new HttpsError("unauthenticated", "Must be signed in.");
    }

    const {
      projectId,
      projectTitle,
      inviterUid,
      inviterName,
      inviteeEmail,
      role,
      permissionTier,
    } = request.data ?? {};

    if (!projectId || !inviteeEmail) {
      throw new HttpsError("invalid-argument", "projectId and inviteeEmail are required.");
    }

    // Verify caller is the project owner
    const projectDoc = await db.collection("projects").doc(projectId).get();
    if (!projectDoc.exists) {
      throw new HttpsError("not-found", "Project not found.");
    }
    const projectData = projectDoc.data() ?? {};
    if (projectData.ownerUid !== caller.uid) {
      throw new HttpsError("permission-denied", "Only the project owner can create invitations.");
    }

    // Generate a UUID v4 using the already-imported crypto module
    const token = crypto.randomUUID();
    const expiresAt = new Date(Date.now() + 7 * 24 * 60 * 60 * 1000); // 7 days

    await db.collection("invitations").doc(token).set({
      projectId,
      projectTitle: projectTitle ?? projectData.title ?? "",
      inviterUid: caller.uid,
      inviterName: inviterName ?? "",
      inviteeEmail,
      role: role ?? "other",
      permissionTier: permissionTier ?? "collaborator",
      status: "pending",
      expiresAt: admin.firestore.Timestamp.fromDate(expiresAt),
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    return {
      token,
      link: `wysebrix://join?token=${token}`,
    };
  },
);

// ── Scheduled: Clean up old notification inbox entries ───────────────────────
// Runs every Sunday at 02:00 UTC. Deletes inbox notifications older than 90
// days that have already been read, to keep Firestore storage costs low.
export const cleanupOldNotifications = onSchedule(
  { schedule: "every sunday 02:00", timeZone: "UTC" },
  async () => {
    const cutoff = admin.firestore.Timestamp.fromDate(
      new Date(Date.now() - 90 * 24 * 60 * 60 * 1000), // 90 days ago
    );
    const usersSnap = await db.collection("users").select().get();
    let totalDeleted = 0;

    for (const userDoc of usersSnap.docs) {
      const uid = userDoc.id;
      let batch = db.batch();
      let batchCount = 0;

      const oldNotifs = await db
        .collection("users").doc(uid).collection("notifications")
        .where("read", "==", true)
        .where("createdAt", "<", cutoff)
        .limit(400) // Stay under 500 batch limit
        .get();

      for (const notif of oldNotifs.docs) {
        batch.delete(notif.ref);
        batchCount++;
        if (batchCount === 400) {
          await batch.commit();
          batch = db.batch();
          batchCount = 0;
        }
      }
      if (batchCount > 0) await batch.commit();
      totalDeleted += oldNotifs.size;
    }

    logger.info(`cleanupOldNotifications: deleted ${totalDeleted} old notifications across ${usersSnap.size} users`);
  },
);

// ── Paystack webhook ─────────────────────────────────────────────────────────
// Receives POST from Paystack servers (charge.success, subscription.create, etc.)
// Verifies the x-paystack-signature HMAC-SHA512 header before processing.
//
// Register the URL in your Paystack Dashboard → Settings → API Keys & Webhooks:
//   https://<region>-<project-id>.cloudfunctions.net/paystackWebhook
//
// The function reads PAYSTACK_SECRET_KEY from Secret Manager (same secret used
// by initPaystackTransaction).
export const paystackWebhook = onRequest(
  { secrets: [paystackSecretKey] },
  async (req, res) => {
    if (req.method !== "POST") {
      res.status(405).send("Method Not Allowed");
      return;
    }

    // Verify HMAC-SHA512 signature
    const secretKey = paystackSecretKey.value();
    const signature = req.headers["x-paystack-signature"] as string | undefined;
    if (!signature || !secretKey) {
      logger.warn("paystackWebhook: missing signature or secret");
      res.status(400).send("Bad Request");
      return;
    }

    const rawBody = JSON.stringify(req.body);
    const expectedSig = crypto
      .createHmac("sha512", secretKey)
      .update(rawBody)
      .digest("hex");

    if (signature !== expectedSig) {
      logger.warn("paystackWebhook: invalid signature — possible spoofed request");
      res.status(401).send("Unauthorized");
      return;
    }

    // Idempotency: use Paystack event reference as key
    const event = req.body as { event?: string; data?: Record<string, unknown> };
    const eventType = event.event ?? "";
    const data = event.data ?? {};
    const reference = (data.reference as string) ?? (data.id as string) ?? "";

    if (reference) {
      const dedupRef = db.doc(`_paystackEvents/${reference}`);
      const existing = await dedupRef.get();
      if (existing.exists) {
        logger.info("paystackWebhook: duplicate event, skipping", { reference });
        res.status(200).send("OK");
        return;
      }
      await dedupRef.set({ eventType, processedAt: admin.firestore.FieldValue.serverTimestamp() });
    }

    try {
      switch (eventType) {
        case "charge.success": {
          // Update the payment record in Firestore to 'completed'
          const metadata = data.metadata as Record<string, string> | undefined;
          const projectId = metadata?.projectId;
          const paymentId = metadata?.paymentId;
          const uid = metadata?.uid;

          if (projectId && paymentId) {
            await db
              .collection("projects").doc(projectId)
              .collection("payments").doc(paymentId)
              .update({ status: "completed", paidAt: admin.firestore.FieldValue.serverTimestamp() });
            logger.info("paystackWebhook: payment marked completed", { projectId, paymentId });
          }

          // Upgrade user subscription tier if this is a plan purchase
          const planTier = metadata?.planTier;
          if (uid && planTier && (planTier === "pro" || planTier === "business")) {
            await db.collection("users").doc(uid).update({ subscriptionTier: planTier });
            logger.info("paystackWebhook: subscription tier upgraded", { uid, planTier });
          }
          break;
        }

        case "subscription.create": {
          // User successfully subscribed — update their tier
          const customer = data.customer as Record<string, string> | undefined;
          const plan = data.plan as Record<string, string> | undefined;
          const customerEmail = customer?.email;
          const planCode = plan?.plan_code ?? "";

          // Map plan codes to tiers (configure these in Paystack dashboard)
          const tierByPlanCode: Record<string, string> = {
            "PLN_pro": "pro",
            "PLN_business": "business",
          };
          const tier = tierByPlanCode[planCode];

          if (customerEmail && tier) {
            try {
              const userRecord = await admin.auth().getUserByEmail(customerEmail);
              await db.collection("users").doc(userRecord.uid).update({ subscriptionTier: tier });
              logger.info("paystackWebhook: subscription.create tier set", { email: customerEmail, tier });
            } catch (e) {
              logger.warn("paystackWebhook: subscription.create — user not found by email", { customerEmail });
            }
          }
          break;
        }

        case "subscription.disable":
        case "subscription.not_renew": {
          // Subscription cancelled — downgrade to free
          const customer2 = data.customer as Record<string, string> | undefined;
          const customerEmail2 = customer2?.email;
          if (customerEmail2) {
            try {
              const userRecord = await admin.auth().getUserByEmail(customerEmail2);
              await db.collection("users").doc(userRecord.uid).update({ subscriptionTier: "free" });
              logger.info("paystackWebhook: subscription cancelled — downgraded to free", { email: customerEmail2 });
            } catch (e) {
              logger.warn("paystackWebhook: subscription.disable — user not found", { customerEmail2 });
            }
          }
          break;
        }

        default:
          logger.info("paystackWebhook: unhandled event type", { eventType });
      }

      res.status(200).send("OK");
    } catch (e: unknown) {
      const err = e as Error;
      logger.error("paystackWebhook: processing error", { eventType, error: err.message });
      res.status(500).send("Internal Server Error");
    }
  },
);

// ── Activate Subscription callable ───────────────────────────────────────────
// Called from upgrade_page.dart after a successful Paystack payment.
// Verifies the payment reference with Paystack API then upgrades the user tier.
export const activateSubscription = onCall(
  { secrets: [paystackSecretKey] },
  async (request) => {
    const uid = request.auth?.uid;
    if (!uid) {
      throw new HttpsError("unauthenticated", "Must be signed in.");
    }

    const { reference, tier } = request.data as {
      reference?: string;
      tier?: string;
    };

    if (!reference) {
      throw new HttpsError("invalid-argument", "reference is required.");
    }
    if (!tier || !["project_pass", "pro", "business"].includes(tier)) {
      throw new HttpsError("invalid-argument", "Invalid tier. Must be project_pass, pro or business.");
    }

    const secretKey = paystackSecretKey.value();
    if (!secretKey) {
      throw new HttpsError("internal", "Payment key not configured.");
    }

    // Verify with Paystack
    let verified = false;
    try {
      const resp = await fetch(
        `https://api.paystack.co/transaction/verify/${encodeURIComponent(reference)}`,
        {
          method: "GET",
          headers: {
            Authorization: `Bearer ${secretKey}`,
            "Content-Type": "application/json",
          },
        },
      );
      const json = (await resp.json()) as { status: boolean; data?: { status?: string } };
      if (json.status && json.data?.status === "success") {
        verified = true;
      }
    } catch (e: unknown) {
      logger.error("activateSubscription: Paystack verify failed", { error: (e as Error).message });
      throw new HttpsError("internal", "Payment verification failed.");
    }

    if (!verified) {
      throw new HttpsError("failed-precondition", "Payment not confirmed by Paystack.");
    }

    const updateData: Record<string, unknown> = {
      subscriptionTier: tier,
      subscriptionUpdatedAt: admin.firestore.FieldValue.serverTimestamp(),
    };
    if (tier === "project_pass") {
      // Project Pass valid for 24 months from activation
      const expiry = new Date();
      expiry.setMonth(expiry.getMonth() + 24);
      updateData["projectPassExpiresAt"] = expiry;
    }
    await db.collection("users").doc(uid).update(updateData);

    logger.info("activateSubscription: subscription activated", { uid, tier, reference });
    return { success: true };
  },
);

// ── Stripe: create PaymentIntent ─────────────────────────────────────────────
// Called by flutter_stripe PaymentSheet before presenting the sheet.
// Returns { clientSecret } — the secret key never leaves the server.
export const createStripePaymentIntent = onCall(
  { secrets: [stripeSecretKey] },
  async (request) => {
    const uid = request.auth?.uid;
    if (!uid) throw new HttpsError("unauthenticated", "Must be signed in.");

    const { amountCents, currency, email, tier } = request.data as {
      amountCents?: number;
      currency?: string;
      email?: string;
      tier?: string;
    };

    if (!amountCents || amountCents <= 0) {
      throw new HttpsError("invalid-argument", "amountCents must be a positive integer.");
    }
    if (!tier || !["project_pass", "pro", "business"].includes(tier)) {
      throw new HttpsError("invalid-argument", "Invalid tier.");
    }

    const key = stripeSecretKey.value();
    if (!key) throw new HttpsError("internal", "Stripe key not configured.");

    const body = new URLSearchParams({
      amount: String(amountCents),
      currency: currency || "usd",
      "metadata[uid]": uid,
      "metadata[tier]": tier,
    });
    if (email) body.set("receipt_email", email);

    const resp = await fetch("https://api.stripe.com/v1/payment_intents", {
      method: "POST",
      headers: {
        Authorization: `Bearer ${key}`,
        "Content-Type": "application/x-www-form-urlencoded",
      },
      body: body.toString(),
    });

    const json = (await resp.json()) as {
      client_secret?: string;
      error?: { message: string };
    };

    if (json.error) {
      logger.error("createStripePaymentIntent: Stripe error", { message: json.error.message });
      throw new HttpsError("internal", json.error.message);
    }

    logger.info("createStripePaymentIntent: intent created", { uid, tier, amountCents });
    return { clientSecret: json.client_secret };
  },
);

// ── Stripe: activate subscription after successful payment ───────────────────
// Called client-side after Stripe PaymentSheet completes successfully.
// Verifies the PaymentIntent status with Stripe, then updates Firestore.
export const activateStripeSubscription = onCall(
  { secrets: [stripeSecretKey] },
  async (request) => {
    const uid = request.auth?.uid;
    if (!uid) throw new HttpsError("unauthenticated", "Must be signed in.");

    const { paymentIntentId, tier } = request.data as {
      paymentIntentId?: string;
      tier?: string;
    };

    if (!paymentIntentId) throw new HttpsError("invalid-argument", "paymentIntentId required.");
    if (!tier || !["project_pass", "pro", "business"].includes(tier)) {
      throw new HttpsError("invalid-argument", "Invalid tier.");
    }

    const key = stripeSecretKey.value();
    if (!key) throw new HttpsError("internal", "Stripe key not configured.");

    // Verify the PaymentIntent with Stripe
    let piStatus: string | undefined;
    let piUid: string | undefined;
    try {
      const resp = await fetch(
        `https://api.stripe.com/v1/payment_intents/${encodeURIComponent(paymentIntentId)}`,
        { headers: { Authorization: `Bearer ${key}` } },
      );
      const pi = (await resp.json()) as {
        status?: string;
        metadata?: { uid?: string; tier?: string };
        error?: { message: string };
      };
      if (pi.error) throw new Error(pi.error.message);
      piStatus = pi.status;
      piUid = pi.metadata?.uid;
    } catch (e: unknown) {
      logger.error("activateStripeSubscription: Stripe verify failed", {
        error: (e as Error).message,
      });
      throw new HttpsError("internal", "Payment verification failed.");
    }

    if (piStatus !== "succeeded") {
      throw new HttpsError("failed-precondition", "Payment not completed.");
    }
    if (piUid !== uid) {
      throw new HttpsError("permission-denied", "PaymentIntent does not belong to this user.");
    }

    const stripeUpdate: Record<string, unknown> = {
      subscriptionTier: tier,
      subscriptionUpdatedAt: admin.firestore.FieldValue.serverTimestamp(),
    };
    if (tier === "project_pass") {
      const expiry = new Date();
      expiry.setMonth(expiry.getMonth() + 24);
      stripeUpdate["projectPassExpiresAt"] = expiry;
    }
    await db.collection("users").doc(uid).update(stripeUpdate);

    logger.info("activateStripeSubscription: activated", { uid, tier, paymentIntentId });
    return { success: true };
  },
);

// ── User data cascade delete ─────────────────────────────────────────────────
// Triggered when a users/{uid} document is deleted.
// Cleans up all data owned by the user across collections.
export const onUserDataDeleted = onDocumentDeleted("users/{uid}", async (event) => {
  const uid = event.params.uid;
  try {
    // Delete all owned projects (+ sub-collections via recursiveDelete)
    const projectsSnap = await db.collection("projects").where("ownerUid", "==", uid).get();
    for (const doc of projectsSnap.docs) {
      await db.recursiveDelete(doc.ref);
    }
    // Delete contracts where owner
    const contractsSnap = await db.collection("contracts").where("ownerUid", "==", uid).get();
    for (const doc of contractsSnap.docs) await doc.ref.delete();
    // Delete PM + builder profiles
    await db.collection("pm_profiles").doc(uid).delete().catch(() => {});
    await db.collection("builder_profiles").doc(uid).delete().catch(() => {});
    // Delete RFQ requests
    const rfqSnap = await db.collection("rfq_requests").where("ownerUid", "==", uid).get();
    for (const doc of rfqSnap.docs) await doc.ref.delete();
    // Delete project templates
    const tmplSnap = await db.collection("project_templates").where("ownerUid", "==", uid).get();
    for (const doc of tmplSnap.docs) await doc.ref.delete();
    logger.info(`onUserDataDeleted: cleanup complete for uid=${uid}`);
  } catch (e: unknown) {
    logger.error("onUserDataDeleted failed", { uid, error: (e as Error).message });
  }
});


// ── Revoke User Sessions ─────────────────────────────────────────────────────
// Callable by the user themselves to revoke all other active sessions.
export const revokeUserSessions = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Must be signed in.");
  }
  const callerUid = request.auth.uid;
  // Users can only revoke their own sessions (or admins can revoke any)
  const targetUid = (request.data as { uid?: string }).uid ?? callerUid;
  const isAdmin = request.auth.token?.admin === true;
  if (targetUid !== callerUid && !isAdmin) {
    throw new HttpsError("permission-denied", "Not authorised.");
  }
  try {
    await admin.auth().revokeRefreshTokens(targetUid);
    logger.info(`revokeUserSessions: tokens revoked for uid=${targetUid}`);
    return { success: true };
  } catch (e: unknown) {
    logger.error("revokeUserSessions failed", { error: (e as Error).message });
    throw new HttpsError("internal", "Failed to revoke sessions.");
  }
});

// ── Daily: demote expired Project Pass users back to free ───────────────────
export const checkExpiredProjectPasses = onSchedule(
  { schedule: "every 24 hours", timeZone: "Africa/Accra" },
  async () => {
    const now = admin.firestore.Timestamp.now();
    const snap = await db
      .collection("users")
      .where("subscriptionTier", "==", "project_pass")
      .where("projectPassExpiresAt", "<=", now)
      .get();

    const batch = db.batch();
    const claimsUpdates: Promise<void>[] = [];

    for (const doc of snap.docs) {
      batch.update(doc.ref, { subscriptionTier: "free" });
      claimsUpdates.push(
        admin.auth().setCustomUserClaims(doc.id, {
          subscriptionTier: "free",
          projectPassExpiresAt: null,
        }),
      );
    }

    await Promise.all([batch.commit(), ...claimsUpdates]);
    logger.info(`checkExpiredProjectPasses: demoted ${snap.size} users`);
  },
);

// ── Project quota enforcement (callable) ─────────────────────────────────────
// Called by CreateProjectPage before creating a project.
// Returns { allowed: true } or throws 'resource-exhausted'.
export const enforceProjectQuota = onCall(
  { enforceAppCheck: false },
  async (request) => {
    const uid = request.auth?.uid;
    if (!uid) throw new HttpsError("unauthenticated", "Sign in required");

    const userDoc = await db.collection("users").doc(uid).get();
    const userData = userDoc.data() ?? {};
    const tier = (userData.subscriptionTier as string | undefined) ?? "free";

    const maxProjects = tier === "pro" || tier === "business" ? 999 : tier === "project_pass" ? 999 : 1;

    const snap = await db
      .collection("projects")
      .where("ownerUid", "==", uid)
      .count()
      .get();

    if (snap.data().count >= maxProjects) {
      throw new HttpsError(
        "resource-exhausted",
        `Your ${tier} plan supports ${maxProjects} project(s). Upgrade to create more.`,
      );
    }
    return { allowed: true };
  },
);
