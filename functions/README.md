# WyseBrix Cloud Functions

## Setup

### Install dependencies
```bash
npm install
```

### Build
```bash
npm run build
```

### Deploy
```bash
firebase deploy --only functions
```

---

## BigQuery Analytics Export (Priority 8)

### Step 1: Install the Firestore → BigQuery Extension

1. Go to Firebase Console → Extensions
2. Search for **"Stream Firestore to BigQuery"** (`firestore-bigquery-export`)
3. Click **Install**

### Step 2: Configure the Extension

During installation, configure the following collections:
- `projects` — mirrors project documents
- `rfq_requests` — mirrors RFQ request documents

Set the BigQuery **dataset ID** to: `wysebrix_analytics`

The extension auto-creates BigQuery tables:
- `wysebrix_analytics.projects_raw`
- `wysebrix_analytics.projects_raw_latest` (view with deduplication)
- `wysebrix_analytics.rfq_requests_raw`

### Step 3: Add Builder Permissions

Grant the Cloud Functions service account the **BigQuery Data Editor** role:

1. Go to GCP Console → IAM & Admin → IAM
2. Find the App Engine default service account (or the Functions service account)
3. Add role: **BigQuery Data Editor**

### Step 4: Install BigQuery Client Library

The `dailyProjectRollup` scheduled function uses `@google-cloud/bigquery`.
It is already in `package.json` — just run `npm install` in the `functions/` directory.

### BigQuery Schema

The `project_summary` table (written daily by `dailyProjectRollup`) has the schema:

| Column | Type | Description |
|---|---|---|
| `ownerUid` | STRING | Firebase Auth UID of the project owner |
| `totalProjects` | INTEGER | Number of projects owned |
| `totalBudgetGhs` | FLOAT | Sum of all project budgets (GHS) |
| `totalSpentGhs` | FLOAT | Sum of all amounts spent (GHS) |
| `reportDate` | DATE | Date the rollup was computed |
| `updatedAt` | TIMESTAMP | When the row was written |

### Example BigQuery Queries

**Per-owner budget utilisation:**
```sql
SELECT
  ownerUid,
  totalProjects,
  totalBudgetGhs,
  totalSpentGhs,
  ROUND(totalSpentGhs / NULLIF(totalBudgetGhs, 0) * 100, 1) AS utilisationPct
FROM wysebrix_analytics.project_summary
WHERE reportDate = CURRENT_DATE()
ORDER BY utilisationPct DESC;
```

**Latest raw projects:**
```sql
SELECT ownerUid, SUM(data.budget) AS totalBudget
FROM wysebrix_analytics.projects_raw_latest
GROUP BY ownerUid
ORDER BY totalBudget DESC;
```

---

## GCP Alerting (Priority 7)

Set up a Log-based Alert for function errors:

1. Go to GCP Console → Logging → Log-based Alerts
2. Create an alert with filter:
   ```
   resource.type="cloud_function"
   severity=ERROR
   ```
3. Set notification channel (email / Slack / PagerDuty)

This will notify you when any Cloud Function trigger logs an `ERROR`-severity entry.

---

## Deployed Functions

| Function | Trigger | Description |
|---|---|---|
| `onUserRoleChange` | Firestore write on `users/{uid}` | Syncs role → custom JWT claim |
| `setUserRoles` | HTTPS Callable | Admin sets user roles |
| `onPhaseCreated` | Firestore create | Notifies owner when phase added |
| `onCostCreated` | Firestore create | Notifies owner when cost entry added |
| `onUpdateCreated` | Firestore create | Notifies owner when update posted |
| `onDeletionRequestCreated` | Firestore create | Notifies owner of deletion request |
| `onDeletionRequestUpdated` | Firestore update | Notifies builder of request resolution |
| `onContractCreated` | Firestore create | Notifies builder of new contract |
| `onContractUpdated` | Firestore update | Notifies owner when contract signed |
| `onProjectUpdated` | Firestore update | Notifies builder when assigned |
| `dailyProjectRollup` | Schedule (02:00 UTC) | Writes per-owner stats to BigQuery |
