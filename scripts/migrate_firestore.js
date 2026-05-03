/*
Migration script for barangay_system Firestore

Usage:
  1. Create a Firebase service account JSON and set env var:
     export GOOGLE_APPLICATION_CREDENTIALS="/path/to/serviceAccountKey.json"
     (Windows PowerShell: $env:GOOGLE_APPLICATION_CREDENTIALS = 'C:\path\to\serviceAccountKey.json')

  2. Run:
     node scripts/migrate_firestore.js

This script will:
 - Ensure each user document has `role` (copied from `type` if present).
 - Normalize approval/status fields: prefer `status`, fall back to `approvalStatus` or `approval`.
 - Normalize transparency_docs metadata: ensure `fileName`, `fileUrl`, `uploadDate`, `uploadedBy`, `barangay` exist.

Be careful: run on a backup or a test project first.
*/

const admin = require('firebase-admin');

if (!process.env.GOOGLE_APPLICATION_CREDENTIALS) {
  console.error('ERROR: Set GOOGLE_APPLICATION_CREDENTIALS env var to your service account JSON file');
  process.exit(1);
}

admin.initializeApp({
  credential: admin.credential.applicationDefault(),
});

const db = admin.firestore();

async function migrateUsers() {
  console.log('Migrating users...');
  const usersSnap = await db.collection('users').get();
  console.log(`Found ${usersSnap.size} users`);
  let updated = 0;
  for (const doc of usersSnap.docs) {
    const data = doc.data();
    const updates = {};
    // role
    if (!data.role && data.type) updates.role = data.type;
    if (!data.role && !data.type) {
      // default to Resident for safety
      updates.role = 'Resident';
    }
    // status normalization
    const rawStatus = (data.status || data.approvalStatus || data.approval || '').toString().toLowerCase();
    if (rawStatus) {
      if (rawStatus.includes('pend')) updates.status = 'pending';
      else if (rawStatus.includes('approv')) updates.status = 'approved';
      else if (rawStatus.includes('reject')) updates.status = 'rejected';
      else updates.status = rawStatus;
    } else if (!data.status) {
      // if absolutely missing, set pending
      updates.status = 'pending';
    }

    // Only write if there are changes
    if (Object.keys(updates).length > 0) {
      await db.collection('users').doc(doc.id).update(updates);
      updated++;
    }
  }
  console.log(`Users migrated. Docs updated: ${updated}`);
}

async function migrateTransparencyDocs() {
  console.log('Migrating transparency_docs...');
  const snap = await db.collection('transparency_docs').get();
  console.log(`Found ${snap.size} docs`);
  let updated = 0;
  for (const doc of snap.docs) {
    const data = doc.data();
    const updates = {};
    if (!data.fileName && data.title) updates.fileName = data.title;
    if (!data.fileUrl && data.url) updates.fileUrl = data.url;
    if (!data.uploadDate && data.timestamp) updates.uploadDate = data.timestamp;
    if (!data.uploadedBy && data.uploadedBy) updates.uploadedBy = data.uploadedBy; // no-op but kept for clarity
    if (!data.barangay && data.barangay === undefined) updates.barangay = 'general';

    if (Object.keys(updates).length > 0) {
      await db.collection('transparency_docs').doc(doc.id).update(updates);
      updated++;
    }
  }
  console.log(`Transparency docs migrated. Docs updated: ${updated}`);
}

async function main() {
  try {
    await migrateUsers();
    await migrateTransparencyDocs();
    console.log('Migration complete.');
    process.exit(0);
  } catch (e) {
    console.error('Migration error:', e);
    process.exit(2);
  }
}

main();
