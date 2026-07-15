/**
 * One-time backfill — writes `searchTerms` onto every existing recipe so the
 * whole catalog becomes searchable (new/edited recipes already index on save).
 *
 * Usage:
 *   1. cd /Users/ukw/Desktop/nommie/backend/functions
 *   2. node backfillSearch.js
 *
 * Mirrors Recipe.searchTerms() in the iOS app.
 */

const admin = require("firebase-admin");
const serviceAccount = require("./nommie-bc531-firebase-adminsdk-fbsvc-f738be5a60.json");

admin.initializeApp({ credential: admin.credential.cert(serviceAccount) });
const db = admin.firestore();

function searchTerms(recipe) {
  const terms = new Set();
  const addWords = (s) => {
    (String(s || "").toLowerCase().match(/[a-z0-9]+/g) || []).forEach((w) => {
      if (w.length >= 2) terms.add(w);
    });
  };

  addWords(recipe.dishName);
  (recipe.tags || []).forEach((t) => {
    terms.add(String(t).toLowerCase());
    addWords(t);
  });
  (recipe.ingredients || []).forEach((ing) => addWords(ing.name));

  const per = Math.max(1, recipe.servings || 1);
  const m = recipe.macros || {};
  const protein = (m.protein || 0) / per;
  const fiber = (m.fiber || 0) / per;
  const carbs = (m.carbs || 0) / per;
  const calories = (m.calories || 0) / per;

  if (protein >= 20) { terms.add("high protein"); terms.add("protein"); }
  if (fiber >= 6) { terms.add("high fiber"); terms.add("fiber"); }
  if (carbs <= 20) terms.add("low carb");
  if (calories <= 400) terms.add("low calorie");

  return [...terms];
}

async function run() {
  const snap = await db.collection("recipes").get();
  console.log(`Found ${snap.size} recipes. Backfilling…`);

  let batch = db.batch();
  let inBatch = 0;
  let total = 0;

  for (const doc of snap.docs) {
    batch.update(doc.ref, { searchTerms: searchTerms(doc.data()) });
    inBatch++;
    total++;
    if (inBatch >= 400) {
      await batch.commit();
      batch = db.batch();
      inBatch = 0;
      console.log(`  …${total} done`);
    }
  }
  if (inBatch > 0) await batch.commit();

  console.log(`\nBackfilled searchTerms on ${total} recipes.`);
}

run().then(() => process.exit(0)).catch((e) => {
  console.error(e);
  process.exit(1);
});
