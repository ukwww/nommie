/**
 * One-time cleanup script — deletes all Firestore data for accounts
 * that were removed directly from the Firebase Auth console.
 *
 * Usage:
 *   1. cd /Users/ukw/Desktop/nommie/backend/functions
 *   2. Edit the UIDS array below with the UIDs you copied from Firebase Auth
 *   3. node cleanupUsers.js
 */

const admin = require("firebase-admin");

// ─── FILL THESE IN ───────────────────────────────────────────────────────────
const UIDS = [
  // "juaZrrVBRvbRxbjYL6JiKZ6eFCp1",
  // "t24LREbQFCQLR0JXptjgniIzyhC2",
 // "gT1f28FGLVRNSKrjH64L1NU8BLS2",
// "bbJrpCjF09crjZE43Rle4RWzS943",
// "ohODa7wwX7eA5aQ0y2yqvy8Htnr1",
// "VjHW7gRvmbOZtOA59hp4pJxqqrG3",
// "7PquVmH7k0bTYv18MLjtKrUg9703",

];
// ─────────────────────────────────────────────────────────────────────────────

admin.initializeApp();
const db = admin.firestore();

async function cleanupUser(uid) {
  console.log(`\nCleaning up UID: ${uid}`);

  // Delete all recipes (and their images — Storage cleanup is separate)
  const recipes = await db.collection("recipes").where("userId", "==", uid).get();
  for (const doc of recipes.docs) {
    await doc.ref.delete();
    console.log(`  deleted recipe ${doc.id}`);
  }

  // Delete all follows where this user is following someone
  const following = await db.collection("follows").where("followerId", "==", uid).get();
  for (const doc of following.docs) { await doc.ref.delete(); }
  console.log(`  deleted ${following.size} following entries`);

  // Delete all follows where this user is being followed
  const followers = await db.collection("follows").where("followingId", "==", uid).get();
  for (const doc of followers.docs) { await doc.ref.delete(); }
  console.log(`  deleted ${followers.size} follower entries`);

  // Delete all saved recipes by this user
  const saved = await db.collection("saved").where("userId", "==", uid).get();
  for (const doc of saved.docs) { await doc.ref.delete(); }
  console.log(`  deleted ${saved.size} saved entries`);

  // Delete the user document
  await db.collection("users").doc(uid).delete();
  console.log(`  deleted user document`);

  console.log(`  done.`);
}

async function main() {
  if (UIDS.length === 0 || UIDS.every(u => u.startsWith("paste"))) {
    console.error("No UIDs provided. Edit the UIDS array in cleanupUsers.js first.");
    process.exit(1);
  }

  for (const uid of UIDS) {
    await cleanupUser(uid);
  }

  console.log("\nAll done. Firebase Auth accounts were already deleted from the console.");
  process.exit(0);
}

main().catch(err => {
  console.error(err);
  process.exit(1);
});
nod