import * as admin from "firebase-admin";
import { onCall } from "firebase-functions/v2/https";
import { onDocumentCreated, onDocumentUpdated } from "firebase-functions/v2/firestore";

// Initialize Admin SDK once
if (admin.apps.length === 0) {
  admin.initializeApp();
}

/**
 * setUserRoles
 * Callable by Admins only.
 * Payload: { uid: string, roles: { builder?: boolean, architect?: boolean, vendor?: boolean, basic?: boolean, admin?: boolean } }
 *
 * Writes custom claims and mirrors to /users/{uid}.
 */
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

  // Sanitize to booleans only
  const allowedKeys = ["basic", "vendor", "architect", "builder", "admin"] as const;
  const claims: Record<string, boolean> = {};
  for (const key of allowedKeys) {
    if (roles[key] != null) claims[key] = !!roles[key];
  }

  // Apply custom claims
  await admin.auth().setCustomUserClaims(uid, {
    ...claims,
    // normalize top-level 'role' (optional):
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

  // Mirror to /users/{uid}
  const db = admin.firestore();
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

// ── Notification helpers ────────────────────────────────────────────────────

const db = admin.firestore();

async function sendToUser(
  uid: string,
  title: string,
  body: string,
  data: Record<string, string>,
): Promise<void> {
  // Always persist to Firestore inbox (even if no FCM token)
  await db.collection("users").doc(uid).collection("notifications").add({
    title,
    body,
    data,
    read: false,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  const snap = await db.collection("users").doc(uid).get();
  const token = snap.data()?.fcmToken as string | undefined;
  if (!token) return;
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

// ── Firestore triggers ──────────────────────────────────────────────────────

// 1. Phase added → notify owner
export const onPhaseCreated = onDocumentCreated(
  "projects/{projectId}/phases/{phaseId}",
  async (event) => {
    const { projectId } = event.params;
    const phase = event.data?.data() ?? {};
    const { ownerUid, title } = await getProject(projectId);
    await sendToUser(
      ownerUid,
      "Phase Added",
      `Builder added phase '${phase.name ?? ""}' to ${title}`,
      { type: "phase_new", projectId },
    );
  },
);

// 2. Cost entry → notify owner
export const onCostCreated = onDocumentCreated(
  "projects/{projectId}/costs/{costId}",
  async (event) => {
    const { projectId } = event.params;
    const cost = event.data?.data() ?? {};
    const { ownerUid, title } = await getProject(projectId);
    const amt = (cost.amountGhs as number ?? 0).toLocaleString("en-GH", {
      maximumFractionDigits: 0,
    });
    await sendToUser(
      ownerUid,
      "New Cost Entry",
      `Builder recorded ₵${amt} for ${cost.category ?? "costs"} on ${title}`,
      { type: "cost_new", projectId },
    );
  },
);

// 3. Update posted → notify owner
export const onUpdateCreated = onDocumentCreated(
  "projects/{projectId}/updates/{updateId}",
  async (event) => {
    const { projectId } = event.params;
    const { ownerUid, title } = await getProject(projectId);
    await sendToUser(
      ownerUid,
      "Project Update",
      `Builder posted an update on ${title}`,
      { type: "update_new", projectId },
    );
  },
);

// 4. Deletion request → notify owner
export const onDeletionRequestCreated = onDocumentCreated(
  "projects/{projectId}/deletionRequests/{reqId}",
  async (event) => {
    const { projectId } = event.params;
    const req = event.data?.data() ?? {};
    const { ownerUid, title } = await getProject(projectId);
    await sendToUser(
      ownerUid,
      "Deletion Request",
      `Builder wants to delete a ${req.itemType ?? "item"} on ${title}`,
      { type: "deletion_new", projectId },
    );
  },
);

// 5. Deletion request resolved → notify builder
export const onDeletionRequestUpdated = onDocumentUpdated(
  "projects/{projectId}/deletionRequests/{reqId}",
  async (event) => {
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
      );
    } else if (after.status === "denied") {
      await sendToUser(
        builderUid,
        "Request Denied",
        `Your deletion request was denied on ${title}`,
        { type: "deletion_denied", projectId },
      );
    }
  },
);

// 6. Contract created → notify builder
export const onContractCreated = onDocumentCreated(
  "contracts/{contractId}",
  async (event) => {
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
    );
  },
);

// 7. Contract signed → notify owner
export const onContractUpdated = onDocumentUpdated(
  "contracts/{contractId}",
  async (event) => {
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
    );
  },
);

// 8. Builder assigned to project → notify builder
export const onProjectUpdated = onDocumentUpdated(
  "projects/{projectId}",
  async (event) => {
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
    );
  },
);