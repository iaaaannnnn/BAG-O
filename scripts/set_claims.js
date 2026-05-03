/*
Usage:
1. Install dependencies: `npm install firebase-admin@latest`
2. Provide a service account JSON via GOOGLE_APPLICATION_CREDENTIALS env var or uncomment the credential line below.
3. Run: `node scripts/set_claims.js`

This script finds users in Firestore where `type == 'Barangay Official'` OR `role == 'Barangay Official'`,
and sets a custom claim `barangay` equal to the user's `barangay` field and `role: 'Barangay Official'`.
*/

const admin = require('firebase-admin');
const {getFirestore} = require('firebase-admin/firestore');

// Option A: Use Application Default Credentials (set GOOGLE_APPLICATION_CREDENTIALS)
admin.initializeApp();

// Option B: initialize with service account file
// const serviceAccount = require('../path/to/serviceAccountKey.json');
// admin.initializeApp({ credential: admin.credential.cert(serviceAccount) });

const db = getFirestore();

async function setClaimsForOfficials() {
  console.log('Scanning users collection for barangay officials...');
  const usersRef = db.collection('users');
  const q = usersRef.where('type', '==', 'Barangay Official');
  const snapshot = await q.get();
  console.log(`Found ${snapshot.size} documents with type==Barangay Official`);

  // Also include users where role field may contain the label
  const q2 = usersRef.where('role', '==', 'Barangay Official');
  const snapshot2 = await q2.get();
  console.log(`Found ${snapshot2.size} documents with role==Barangay Official`);

  const docs = new Map();
  snapshot.forEach(doc => docs.set(doc.id, doc));
  snapshot2.forEach(doc => docs.set(doc.id, doc));

  console.log(`Total unique officials to process: ${docs.size}`);

  for (const [uid, doc] of docs.entries()) {
    try {
      const data = doc.data();
      const barangay = data.barangay || '';
      if (!barangay) {
        console.warn(`Skipping ${uid}: no barangay field present`);
        continue;
      }
      const claims = { barangay: barangay, role: 'Barangay Official' };
      await admin.auth().setCustomUserClaims(uid, claims);
      console.log(`Set claims for ${uid}: ${JSON.stringify(claims)}`);
    } catch (e) {
      console.error(`Error setting claims for ${uid}:`, e);
    }
  }

  console.log('Done. Note: users need to sign out and sign in to receive new claims in their ID token.');
}

setClaimsForOfficials().catch(err => {
  console.error('Fatal error executing script:', err);
  process.exit(1);
});
