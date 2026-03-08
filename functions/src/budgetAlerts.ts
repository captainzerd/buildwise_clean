// functions/src/budgetAlerts.ts
// Cloud Function: fires when amountSpent changes on a project document.
// Sends a notification to the project owner when budget thresholds are crossed.

import * as admin from "firebase-admin";
import { logger } from "firebase-functions";
import { onDocumentUpdated } from "firebase-functions/v2/firestore";

const db = admin.firestore();

export const budgetAlertTrigger = onDocumentUpdated(
  "projects/{projectId}",
  async (event) => {
    const before = event.data?.before?.data();
    const after = event.data?.after?.data();
    if (!before || !after) return;

    const projectId = event.params.projectId;

    // Only run if amountSpent changed
    if (before.amountSpent === after.amountSpent) return;

    const budget =
      (after.budget as number) || (after.estimateTotalGhs as number) || 0;
    if (budget === 0) return;

    const spendPct = ((after.amountSpent as number) / budget) * 100;

    // Count completed phases
    const phasesSnap = await db
      .collection("projects")
      .doc(projectId)
      .collection("phases")
      .get();
    const totalPhases = phasesSnap.size;
    const completedPhases = phasesSnap.docs.filter(
      (d) => d.data().status === "completed",
    ).length;
    const completionPct =
      totalPhases > 0 ? (completedPhases / totalPhases) * 100 : 0;

    const ownerUid = after.ownerUid as string;
    const projectTitle = after.title as string;

    if (!ownerUid) {
      logger.warn("budgetAlertTrigger: ownerUid missing", { projectId });
      return;
    }

    const notifBase = {
      projectId,
      type: "budgetAlert",
      read: false,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    };

    try {
      // Alert thresholds:
      // 90%+ spend, any completion → critical
      // 75%+ spend but <50% complete → high
      // 50%+ spend but <30% complete → medium
      if (spendPct >= 90) {
        await db
          .collection("users")
          .doc(ownerUid)
          .collection("notifications")
          .add({
            ...notifBase,
            title: "Critical: Budget nearly exhausted",
            body: `"${projectTitle}" has used ${spendPct.toFixed(0)}% of budget. Review immediately.`,
            severity: "critical",
          });
        logger.info("budgetAlertTrigger: critical alert sent", {
          projectId,
          spendPct,
        });
      } else if (spendPct >= 75 && completionPct < 50) {
        await db
          .collection("users")
          .doc(ownerUid)
          .collection("notifications")
          .add({
            ...notifBase,
            title: "Budget risk detected",
            body: `"${projectTitle}" has used ${spendPct.toFixed(0)}% of budget but only ${completionPct.toFixed(0)}% of phases are complete.`,
            severity: "high",
          });
        logger.info("budgetAlertTrigger: high alert sent", {
          projectId,
          spendPct,
          completionPct,
        });
      } else if (spendPct >= 50 && completionPct < 30) {
        await db
          .collection("users")
          .doc(ownerUid)
          .collection("notifications")
          .add({
            ...notifBase,
            title: "Budget caution",
            body: `"${projectTitle}" has used ${spendPct.toFixed(0)}% of budget but only ${completionPct.toFixed(0)}% of phases are complete.`,
            severity: "medium",
          });
        logger.info("budgetAlertTrigger: medium alert sent", {
          projectId,
          spendPct,
          completionPct,
        });
      }
    } catch (e: unknown) {
      logger.error("budgetAlertTrigger: failed to write notification", {
        projectId,
        error: (e as Error).message,
      });
    }
  },
);
