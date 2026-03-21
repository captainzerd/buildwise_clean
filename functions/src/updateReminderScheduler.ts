// functions/src/updateReminderScheduler.ts
//
// Runs daily at 08:00 UTC.
// For each active project with updateFrequencyDays > 0:
//   - Finds the most recent project_updates subcollection doc.
//   - If the builder is overdue: notifies the builder.
//   - If 48 h+ past due: also notifies the project owner.
import * as admin from "firebase-admin";
import { onSchedule } from "firebase-functions/v2/scheduler";
import { logger } from "firebase-functions";

// Ensure the Admin SDK is initialised (index.ts initialises it first; this
// guard prevents a double-init if this module is ever loaded standalone).
if (admin.apps.length === 0) {
  admin.initializeApp();
}

const db = admin.firestore();

export const updateReminderScheduler = onSchedule(
  { schedule: "0 8 * * *", timeZone: "UTC", region: "europe-west1" },
  async () => {
    const now = admin.firestore.Timestamp.now();

    const projectsSnap = await db
      .collection("projects")
      .where("status", "==", "active")
      .where("updateFrequencyDays", ">", 0)
      .get();

    const tasks: Promise<void>[] = [];

    for (const projectDoc of projectsSnap.docs) {
      const project = projectDoc.data();
      const projectId = projectDoc.id;
      const updateFrequencyDays = project.updateFrequencyDays as number;

      // Get the most recent project update.
      const updatesSnap = await db
        .collection("projects")
        .doc(projectId)
        .collection("project_updates")
        .orderBy("timestamp", "desc")
        .limit(1)
        .get();

      let daysSinceLastUpdate: number;
      if (updatesSnap.empty) {
        // No updates ever posted — measure from project creation date.
        const createdAt = (
          project.createdAt as admin.firestore.Timestamp
        ).toDate();
        daysSinceLastUpdate =
          (now.toDate().getTime() - createdAt.getTime()) /
          (1000 * 60 * 60 * 24);
      } else {
        const lastUpdate = (
          updatesSnap.docs[0].data().timestamp as admin.firestore.Timestamp
        ).toDate();
        daysSinceLastUpdate =
          (now.toDate().getTime() - lastUpdate.getTime()) /
          (1000 * 60 * 60 * 24);
      }

      if (daysSinceLastUpdate <= updateFrequencyDays) continue; // Still on time.

      const projectTitle = project.title as string;

      // Notify builder.
      if (project.assignedBuilderUid) {
        tasks.push(
          sendNotification(db, project.assignedBuilderUid as string, {
            title: "Update required",
            body: `Your client is waiting for a project update on "${projectTitle}"`,
            projectId,
          }),
        );
      }

      // If 48 h+ past due, also notify the project owner.
      if (daysSinceLastUpdate >= updateFrequencyDays + 2 && project.ownerUid) {
        tasks.push(
          sendNotification(db, project.ownerUid as string, {
            title: "No update received",
            body: `No update received for "${projectTitle}" in ${Math.floor(daysSinceLastUpdate)} days`,
            projectId,
          }),
        );
      }
    }

    await Promise.all(tasks);
    logger.info(
      `updateReminderScheduler: processed ${projectsSnap.docs.length} active projects`,
    );
  },
);

async function sendNotification(
  firestoreDb: admin.firestore.Firestore,
  uid: string,
  payload: { title: string; body: string; projectId: string },
): Promise<void> {
  // Write to the user's notifications subcollection so the app's real-time
  // listener picks it up, and so the FCM send in index.ts:sendToUser fires.
  await firestoreDb
    .collection("users")
    .doc(uid)
    .collection("notifications")
    .add({
      title: payload.title,
      body: payload.body,
      projectId: payload.projectId,
      type: "updateReminder",
      read: false,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
}
