// Nommie Cloud Functions.
//
// estimateMacros: a Callable Function that keeps the OpenAI API key server-side.
// The iOS app calls this instead of talking to OpenAI directly, so the key is
// never shipped inside the app binary.
//
// The key is stored as a Firebase secret named OPENAI_API_KEY. Set it once with:
//   firebase functions:secrets:set OPENAI_API_KEY
// then deploy with:
//   firebase deploy --only functions

const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { onDocumentCreated, onDocumentDeleted, onDocumentUpdated } = require("firebase-functions/v2/firestore");
const { defineSecret } = require("firebase-functions/params");
const admin = require("firebase-admin");

if (!admin.apps.length) admin.initializeApp();

const OPENAI_API_KEY = defineSecret("OPENAI_API_KEY");


// Writes an in-app activity notification and (best effort) sends the push.
// All notification docs are created server-side only — clients just read.
// sendPush: false keeps it bell-only (used for friend-activity fan-outs).
async function notifyUser(recipientId, { type, actorId, actorUsername, recipeId = null, dishName = null, preview = null, targetUsername = null, sendPush = true, title = null, body = null }) {
  const db = admin.firestore();

  await db.collection("notifications").add({
    recipientId,
    type,
    actorId,
    actorUsername: actorUsername ?? "",
    recipeId,
    dishName,
    preview,
    targetUsername,
    read: false,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  }).catch(() => {});

  if (!sendPush || !title) return;

  const recipientDoc = await db.collection("users").doc(recipientId).get();
  const fcmToken = recipientDoc.data()?.fcmToken;
  if (!fcmToken) return;

  await admin.messaging().send({
    token: fcmToken,
    notification: { title, body },
    data: { type, ...(recipeId ? { recipeId } : {}), actorId },
    apns: { payload: { aps: { sound: "default" } } },
  }).catch(() => {});
}

// Delivers a notification to everyone who follows the actor, skipping the
// actor and anyone in excludeIds (e.g. the recipe owner, who already got a
// direct notification).
async function fanOutToFollowers(actorId, excludeIds, payload) {
  const followersSnap = await admin.firestore().collection("follows")
    .where("followingId", "==", actorId)
    .get();

  const skip = new Set([actorId, ...excludeIds.filter(Boolean)]);
  for (const doc of followersSnap.docs) {
    const followerId = doc.data().followerId;
    if (!followerId || skip.has(followerId)) continue;
    await notifyUser(followerId, payload);
  }
}

// Recomputes the two most recent top-level comments denormalized onto the
// recipe doc, so the feed can preview them without extra queries.
async function refreshRecentComments(recipeId) {
  const db = admin.firestore();
  const snap = await db.collection("comments")
    .where("recipeId", "==", recipeId)
    .get();

  const topLevel = snap.docs
    .map((d) => d.data())
    .filter((c) => !c.parentCommentId)
    .sort((a, b) => (b.createdAt?.toMillis?.() ?? 0) - (a.createdAt?.toMillis?.() ?? 0));

  const recent = topLevel.slice(0, 2).map((c) => ({
    userId: c.userId ?? "",
    username: c.username ?? "",
    text: String(c.text ?? "").slice(0, 120),
  }));

  await db.collection("recipes").doc(recipeId).update({ recentComments: recent }).catch(() => {});
}

// Parses @username mentions out of text and notifies each real, distinct
// user — skipping the author and any handles in excludeUsernames.
async function notifyMentions({ text, authorId, authorUsername, recipeId, dishName, excludeUsernames = [] }) {
  const handles = [...new Set(
    (String(text || "").match(/@([a-zA-Z0-9_]+)/g) || []).map((h) => h.slice(1).toLowerCase())
  )];
  if (handles.length === 0) return;

  const exclude = new Set(
    [authorUsername, ...excludeUsernames].filter(Boolean).map((u) => u.toLowerCase())
  );
  const db = admin.firestore();

  for (const handle of handles) {
    if (exclude.has(handle)) continue;
    const snap = await db.collection("users").where("username", "==", handle).limit(1).get();
    const doc = snap.docs[0];
    if (!doc || doc.id === authorId) continue;

    await notifyUser(doc.id, {
      type: "mention",
      actorId: authorId,
      actorUsername: authorUsername,
      recipeId,
      dishName,
      title: "You were mentioned",
      body: `@${authorUsername ?? "Someone"} mentioned you in ${dishName}.`,
    });
  }
}

// Notify a user when someone follows them
exports.onFollowCreated = onDocumentCreated("follows/{docId}", async (event) => {
  const data = event.data.data();
  const followerId  = data.followerId;
  const followingId = data.followingId;

  const followerDoc = await admin.firestore().collection("users").doc(followerId).get();
  const followerUsername = followerDoc.data()?.username ?? "Someone";

  await notifyUser(followingId, {
    type: "follow",
    actorId: followerId,
    actorUsername: followerUsername,
    title: "New follower",
    body: `@${followerUsername} started following you.`,
  });
});

// Username changes — sweep the new name onto everything that denormalizes it:
// the user's own recipes ("Plated by") and replate attributions on other
// people's recipes. Commits in chunks to stay under the 500-write batch limit.
exports.onUserUpdated = onDocumentUpdated("users/{userId}", async (event) => {
  const before = event.data.before.data();
  const after = event.data.after.data();
  if (!before || !after || before.username === after.username) return;

  const uid = event.params.userId;
  const db = admin.firestore();

  const [ownRecipes, replatesOfTheirs] = await Promise.all([
    db.collection("recipes").where("userId", "==", uid).get(),
    db.collection("recipes").where("replateMeta.originalUserId", "==", uid).get(),
  ]);

  const updates = [];
  ownRecipes.docs.forEach((d) => updates.push({ ref: d.ref, data: { username: after.username } }));
  replatesOfTheirs.docs.forEach((d) => updates.push({ ref: d.ref, data: { "replateMeta.originalUsername": after.username } }));

  for (let i = 0; i < updates.length; i += 400) {
    const batch = db.batch();
    updates.slice(i, i + 400).forEach((u) => batch.update(u.ref, u.data));
    await batch.commit();
  }
});

// Likes — maintain the denormalized counter + recent likers on the recipe doc,
// and notify the recipe owner. Doc ID is "{userId}_{recipeId}".
exports.onLikeCreated = onDocumentCreated("likes/{docId}", async (event) => {
  const data = event.data.data();
  const { userId, username, recipeId } = data;
  if (!userId || !recipeId) return;

  const recipeRef = admin.firestore().collection("recipes").doc(recipeId);
  const recipeSnap = await recipeRef.get();
  if (!recipeSnap.exists) return;

  await recipeRef.update({
    likeCount: admin.firestore.FieldValue.increment(1),
    recentLikers: admin.firestore.FieldValue.arrayUnion({ userId, username: username ?? "" }),
  }).catch(() => {});

  // Notify the owner (never for self-likes)
  const recipe = recipeSnap.data();
  if (recipe.userId === userId) return;

  await notifyUser(recipe.userId, {
    type: "like",
    actorId: userId,
    actorUsername: username,
    recipeId,
    dishName: recipe.dishName,
    title: "New like",
    body: `@${username ?? "Someone"} liked your ${recipe.dishName}.`,
  });

  // Friend activity: the liker's followers hear about it (bell only, no push)
  await fanOutToFollowers(userId, [recipe.userId], {
    type: "friend_like",
    actorId: userId,
    actorUsername: username,
    recipeId,
    dishName: recipe.dishName,
    targetUsername: recipe.username,
    sendPush: false,
  });
});

exports.onLikeDeleted = onDocumentDeleted("likes/{docId}", async (event) => {
  const data = event.data.data();
  const { userId, username, recipeId } = data;
  if (!userId || !recipeId) return;

  await admin.firestore().collection("recipes").doc(recipeId).update({
    likeCount: admin.firestore.FieldValue.increment(-1),
    recentLikers: admin.firestore.FieldValue.arrayRemove({ userId, username: username ?? "" }),
  }).catch(() => {});
});

// Saves — aggregate count on the recipe + a notification to the owner.
exports.onSaveCreated = onDocumentCreated("saved/{docId}", async (event) => {
  const data = event.data.data();
  const recipeId = data?.recipeId;
  const saverId = data?.userId;
  if (!recipeId) return;

  const db = admin.firestore();
  const recipeSnap = await db.collection("recipes").doc(recipeId).get();

  await db.collection("recipes").doc(recipeId).update({
    saveCount: admin.firestore.FieldValue.increment(1),
  }).catch(() => {});

  if (!recipeSnap.exists || !saverId) return;
  const recipe = recipeSnap.data();
  if (recipe.userId === saverId) return;

  const saverDoc = await db.collection("users").doc(saverId).get();
  const saverUsername = saverDoc.data()?.username ?? "Someone";

  await notifyUser(recipe.userId, {
    type: "save",
    actorId: saverId,
    actorUsername: saverUsername,
    recipeId,
    dishName: recipe.dishName,
    title: "Recipe saved",
    body: `@${saverUsername} saved your ${recipe.dishName}.`,
  });
});

exports.onSaveDeleted = onDocumentDeleted("saved/{docId}", async (event) => {
  const recipeId = event.data.data()?.recipeId;
  if (!recipeId) return;
  await admin.firestore().collection("recipes").doc(recipeId).update({
    saveCount: admin.firestore.FieldValue.increment(-1),
  }).catch(() => {});
});

// Every new recipe: notify the author's followers (with push). For replates,
// also credit the original author and keep their replateCount current.
exports.onReplateCreated = onDocumentCreated("recipes/{recipeId}", async (event) => {
  const data = event.data.data();
  const authorId = data.userId;
  const authorUsername = data.username;

  if (data.replateMeta) {
    const originalRecipeId = data.replateMeta.originalRecipeId;
    const originalUserId  = data.replateMeta.originalUserId;
    const originalDishName = data.replateMeta.originalDishName;

    if (originalRecipeId) {
      await admin.firestore().collection("recipes").doc(originalRecipeId).update({
        replateCount: admin.firestore.FieldValue.increment(1),
      }).catch(() => {});
    }

    // Don't notify when someone replates their own recipe
    if (authorId !== originalUserId) {
      await notifyUser(originalUserId, {
        type: "replate",
        actorId: authorId,
        actorUsername: authorUsername,
        recipeId: event.params.recipeId,
        dishName: originalDishName,
        title: "Your recipe was replated",
        body: `@${authorUsername} cooked your ${originalDishName}.`,
      });
    }
  }

  // New-plate fan-out to the author's followers, push included. The original
  // author of a replate is excluded — they just got the replate notification.
  await fanOutToFollowers(authorId, [data.replateMeta?.originalUserId], {
    type: "new_recipe",
    actorId: authorId,
    actorUsername: authorUsername,
    recipeId: event.params.recipeId,
    dishName: data.dishName,
    sendPush: true,
    title: "New plate",
    body: `@${authorUsername} plated ${data.dishName}.`,
  });

  // Notify anyone @mentioned in the notes.
  await notifyMentions({
    text: data.notes,
    authorId,
    authorUsername,
    recipeId: event.params.recipeId,
    dishName: data.dishName,
  });
});

// When a recipe's notes are edited, notify anyone newly @mentioned.
exports.onRecipeUpdated = onDocumentUpdated("recipes/{recipeId}", async (event) => {
  const before = event.data.before.data();
  const after = event.data.after.data();
  if (!before || !after) return;
  if ((before.notes || "") === (after.notes || "")) return;

  const alreadyMentioned = ((before.notes || "").match(/@([a-zA-Z0-9_]+)/g) || [])
    .map((h) => h.slice(1));

  await notifyMentions({
    text: after.notes,
    authorId: after.userId,
    authorUsername: after.username,
    recipeId: event.params.recipeId,
    dishName: after.dishName,
    excludeUsernames: alreadyMentioned,
  });
});

// Recipe deletion — decrement the original's replateCount if this was a
// replate, and sweep the recipe's comments and likes so nothing dangles.
exports.onRecipeDeleted = onDocumentDeleted("recipes/{recipeId}", async (event) => {
  const data = event.data.data();
  const db = admin.firestore();

  const originalRecipeId = data?.replateMeta?.originalRecipeId;
  if (originalRecipeId) {
    await db.collection("recipes").doc(originalRecipeId).update({
      replateCount: admin.firestore.FieldValue.increment(-1),
    }).catch(() => {});
  }

  const [comments, likes] = await Promise.all([
    db.collection("comments").where("recipeId", "==", event.params.recipeId).get(),
    db.collection("likes").where("recipeId", "==", event.params.recipeId).get(),
  ]);
  const refs = [...comments.docs, ...likes.docs].map((d) => d.ref);
  for (let i = 0; i < refs.length; i += 400) {
    const batch = db.batch();
    refs.slice(i, i + 400).forEach((ref) => batch.delete(ref));
    await batch.commit();
  }
});

// Comments — maintain the count on the recipe, notify the owner, and notify
// the parent comment's author for replies (deduped when they're the owner).
exports.onCommentCreated = onDocumentCreated("comments/{commentId}", async (event) => {
  const data = event.data.data();
  const { recipeId, userId, username, text, parentCommentId } = data;
  if (!recipeId || !userId) return;

  const db = admin.firestore();
  const recipeSnap = await db.collection("recipes").doc(recipeId).get();

  await db.collection("recipes").doc(recipeId).update({
    commentCount: admin.firestore.FieldValue.increment(1),
  }).catch(() => {});
  await refreshRecentComments(recipeId);

  if (!recipeSnap.exists) return;
  const recipe = recipeSnap.data();
  const previewText = String(text ?? "").slice(0, 80);

  // Reply → notify the parent comment's author
  let parentAuthorId = null;
  if (parentCommentId) {
    const parentSnap = await db.collection("comments").doc(parentCommentId).get();
    parentAuthorId = parentSnap.data()?.userId ?? null;
    if (parentAuthorId && parentAuthorId !== userId) {
      await notifyUser(parentAuthorId, {
        type: "reply",
        actorId: userId,
        actorUsername: username,
        recipeId,
        dishName: recipe.dishName,
        preview: previewText,
        title: "New reply",
        body: `@${username ?? "Someone"} replied to your comment: "${previewText}"`,
      });
    }
  }

  // Notify the recipe owner (skip self-comments and skip if they were
  // already notified as the parent author)
  if (recipe.userId !== userId && recipe.userId !== parentAuthorId) {
    await notifyUser(recipe.userId, {
      type: "comment",
      actorId: userId,
      actorUsername: username,
      recipeId,
      dishName: recipe.dishName,
      preview: previewText,
      title: "New comment",
      body: `@${username ?? "Someone"} on your ${recipe.dishName}: "${previewText}"`,
    });
  }

  // Friend activity for top-level comments (bell only, no push)
  if (!parentCommentId) {
    await fanOutToFollowers(userId, [recipe.userId], {
      type: "friend_comment",
      actorId: userId,
      actorUsername: username,
      recipeId,
      dishName: recipe.dishName,
      preview: previewText,
      targetUsername: recipe.username,
      sendPush: false,
    });
  }

  // Notify anyone @mentioned in the comment (skip the recipe owner and parent
  // author, already notified above).
  const excludeMentions = [];
  if (recipe.userId !== userId) {
    const ownerDoc = await db.collection("users").doc(recipe.userId).get();
    if (ownerDoc.data()?.username) excludeMentions.push(ownerDoc.data().username);
  }
  await notifyMentions({
    text,
    authorId: userId,
    authorUsername: username,
    recipeId,
    dishName: recipe.dishName,
    excludeUsernames: excludeMentions,
  });
});

exports.onCommentDeleted = onDocumentDeleted("comments/{commentId}", async (event) => {
  const recipeId = event.data.data()?.recipeId;
  if (!recipeId) return;
  await admin.firestore().collection("recipes").doc(recipeId).update({
    commentCount: admin.firestore.FieldValue.increment(-1),
  }).catch(() => {});
  await refreshRecentComments(recipeId);
});

// Comment likes — notify the comment's author when someone new likes it.
exports.onCommentUpdated = onDocumentUpdated("comments/{commentId}", async (event) => {
  const before = event.data.before.data();
  const after = event.data.after.data();
  if (!before || !after) return;

  const beforeLikes = new Set(before.likedBy || []);
  const newLikers = (after.likedBy || []).filter((id) => !beforeLikes.has(id));
  if (newLikers.length === 0) return;

  const authorId = after.userId;
  const preview = String(after.text ?? "").slice(0, 80);
  const db = admin.firestore();

  for (const likerId of newLikers) {
    if (likerId === authorId) continue;
    const likerDoc = await db.collection("users").doc(likerId).get();
    const likerUsername = likerDoc.data()?.username ?? "Someone";

    await notifyUser(authorId, {
      type: "comment_like",
      actorId: likerId,
      actorUsername: likerUsername,
      recipeId: after.recipeId,
      preview,
      title: "Comment liked",
      body: `@${likerUsername} liked your comment.`,
    });
  }
});

// Drafts an ingredient list from the user's written cooking steps.
// Quantities are copied only when the text states them — never invented.
exports.extractIngredients = onCall({ secrets: [OPENAI_API_KEY], invoker: "public" }, async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Sign in to draft ingredients.");
  }

  const steps = String(request.data?.steps ?? "").trim();
  if (!steps) {
    throw new HttpsError("invalid-argument", "No steps provided.");
  }
  const dishName = String(request.data?.dishName ?? "").trim();

  const systemMessage = `You extract ingredient lists from home-cooking instructions.

RULES:
- List every distinct food or drink ingredient the instructions mention or clearly use.
- quantity: copy the amount ONLY when the text states one ("3 tbsp soy sauce" → "3 tbsp"). If no amount is stated, use "".
- NEVER invent, guess, or infer amounts that are not written.
- Each ingredient appears once. If it is mentioned multiple times with stated amounts in the same unit, sum them; otherwise keep the first stated amount.
- Exclude plain water unless it is a core component (broth and stock DO count as ingredients).
- Exclude equipment, techniques, temperatures, and serving suggestions.
- Keep names short and natural, preserving the cook's wording ("green onion", not "2 stalks of fresh sliced green onion").
- List ingredients in the order they first appear.

Return ONLY this JSON shape: {"ingredients": [{"name": "...", "quantity": "..."}]}`;

  const userPrompt =
    (dishName ? `Dish name: "${dishName}".\n` : "") +
    `Cooking steps:\n${steps}\n\nExtract the ingredient list as JSON.`;

  let response;
  try {
    response = await fetch("https://api.openai.com/v1/chat/completions", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "Authorization": `Bearer ${OPENAI_API_KEY.value()}`,
      },
      body: JSON.stringify({
        model: "gpt-4o",
        messages: [
          { role: "system", content: systemMessage },
          { role: "user", content: userPrompt },
        ],
        temperature: 0,
        max_tokens: 700,
        response_format: { type: "json_object" },
      }),
    });
  } catch (err) {
    throw new HttpsError("unavailable", "Couldn't reach the ingredient drafter.");
  }

  if (!response.ok) {
    throw new HttpsError("internal", "The ingredient drafter returned an error.");
  }

  const completion = await response.json();
  const content = completion.choices?.[0]?.message?.content ?? "";

  let parsed;
  try {
    parsed = JSON.parse(content);
  } catch (err) {
    throw new HttpsError("internal", "Couldn't read the ingredient draft.");
  }

  const list = Array.isArray(parsed.ingredients) ? parsed.ingredients : [];
  return {
    ingredients: list
      .filter((i) => typeof i?.name === "string" && i.name.trim() !== "")
      .slice(0, 30)
      .map((i) => ({
        name: String(i.name).trim(),
        quantity: typeof i.quantity === "string" ? i.quantity.trim() : "",
      })),
  };
});

exports.estimateMacros = onCall({ secrets: [OPENAI_API_KEY], invoker: "public" }, async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Sign in to estimate macros.");
  }

  const ingredients = String(request.data?.ingredients ?? "").trim();
  if (!ingredients) {
    throw new HttpsError("invalid-argument", "No ingredients provided.");
  }

  const dishName = String(request.data?.dishName ?? "").trim();
  const servings = Math.max(1, parseInt(request.data?.servings ?? "1", 10) || 1);

  const dishContext = dishName ? `Dish name: "${dishName}". ` : "";
  const servingContext = servings > 1
    ? `This recipe makes ${servings} servings — estimate the TOTAL for the whole batch, not per serving. `
    : "This recipe makes 1 serving — estimate the total macros. ";

  const systemMessage = `You are a meticulous nutrition analyst. Estimate the nutritional content of home-cooked dishes from their ingredient list, matching USDA FoodData Central values as closely as possible.

METHOD — follow these steps every time:
1. Parse each listed ingredient and its quantity. Convert every quantity to grams.
2. For each ingredient, recall its USDA per-100g values (calories, protein, carbs, fat, fiber, sugar) and scale to the gram amount.
3. Sum across all ingredients to get recipe totals.
4. Cross-check: calories should roughly equal 4×protein + 4×carbs + 9×fat (within ~10%), and fiber and sugar must each be ≤ carbs. If a check fails, find and fix the error before answering.

STRICT RULES:
- Include ONLY the listed ingredients. NEVER add cooking oil, butter, salt, marinades, garnishes, or sides that are not listed.
- Quantities are for the WHOLE recipe. Never scale to or from a single serving yourself.
- Use raw/uncooked nutrition values unless an ingredient explicitly says cooked.
- Water absorbed or lost in cooking does not change macros. Ignore the cooking method except to identify ingredients.
- The dish name only helps disambiguate ingredients. NEVER estimate from the dish name or inflate numbers toward a "typical" restaurant version of the dish.
- Assume modest home-cooking amounts. For vague quantities use the smallest common size:
  '1 can' tuna = 142 g drained · '1 can' beans = 240 g drained · '1 chicken breast' = 170 g raw
  '1 egg' = 50 g · '1 slice' bread = 40 g · '1 tbsp' oil or butter = 14 g · '1 tsp' = 5 g
  '1 cup' cooked rice = 160 g · '1 cup' uncooked rice = 185 g · '1 cup' milk = 244 g
  '1 clove' garlic = 5 g · 'a handful' = 30 g · 'a splash' = 5 g · 'a drizzle' oil = 7 g
- When torn between two plausible values, choose the LOWER one.

REFERENCE ANCHORS (USDA, per 100 g — interpolate for similar foods):
chicken breast raw 120 kcal/22.5P/0C/2.6F/0fib/0sug · ground beef 85/15 raw 215/18.6/0/15/0/0
salmon raw 208/20/0/13/0/0 · egg 143/12.6/0.7/9.5/0/0.4 · tuna canned in water 116/25.5/0/0.8/0/0
white rice cooked 130/2.7/28/0.3/0.4/0.1 · dry pasta 371/13/75/1.5/3.2/2.7 · white bread 265/9/49/3.2/2.7/5
oil (any) 884/0/0/100/0/0 · butter 717/0.9/0.1/81/0/0.1 · cheddar 403/25/1.3/33/0/0.5
whole milk 61/3.2/4.8/3.3/0/5.1 · greek yogurt plain 59/10/3.6/0.4/0/3.2 · oats dry 389/17/66/7/10.6/1
soy sauce 53/8/4.9/0.6/0.8/0.4 · white sugar 387/0/100/0/0/100 · honey 304/0.3/82/0/0.2/82
potato 77/2/17/0.1/2.2/0.8 · onion 40/1.1/9.3/0.1/1.7/4.2 · avocado 160/2/8.5/14.7/6.7/0.7
banana 89/1.1/23/0.3/2.6/12 · mayo 680/1/0.6/75/0/0.6 · mirin 258/0.2/43/0/0/43

OUTPUT — a single JSON object, nothing else:
{"working": "<one short line per ingredient: grams and its six values, then summed totals, then the 4/4/9 check>", "calories": <int>, "protein": <int>, "carbs": <int>, "fat": <int>, "fiber": <int>, "sugar": <int>}
The six numeric fields are recipe TOTALS rounded to integers.

EXAMPLE
Input: Dish name: "Tuna salad sandwich". This recipe makes 1 serving — estimate the total macros. Ingredients (total for the whole recipe): 1 can tuna, 1 tbsp mayo, 2 slices bread.
Output: {"working": "tuna 142g: 165/36.2/0/1.1/0/0; mayo 14g: 95/0.1/0.1/10.5/0/0.1; bread 80g: 212/7.2/39.2/2.6/2.2/4; totals 472/43.5/39.3/14.2/2.2/4.1; check 4(43.5)+4(39.3)+9(14.2)=459 ~ 472 ok", "calories": 472, "protein": 44, "carbs": 39, "fat": 14, "fiber": 2, "sugar": 4}`;

  const prompt =
    `${dishContext}${servingContext}` +
    `Ingredients (total for the whole recipe): ${ingredients}. ` +
    `Work through the METHOD, then return the single JSON object.`;

  let response;
  try {
    response = await fetch("https://api.openai.com/v1/chat/completions", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "Authorization": `Bearer ${OPENAI_API_KEY.value()}`,
      },
      body: JSON.stringify({
        model: "gpt-4o",
        messages: [
          { role: "system", content: systemMessage },
          { role: "user", content: prompt },
        ],
        temperature: 0,
        max_tokens: 1200,
        response_format: { type: "json_object" },
      }),
    });
  } catch (err) {
    throw new HttpsError("unavailable", "Couldn't reach the macro estimator.");
  }

  if (!response.ok) {
    throw new HttpsError("internal", "The macro estimator returned an error.");
  }

  const completion = await response.json();
  const content = completion.choices?.[0]?.message?.content ?? "";

  let parsed;
  try {
    parsed = JSON.parse(content);
  } catch (err) {
    throw new HttpsError("internal", "Couldn't read the macro estimate.");
  }

  const toInt = (v) => (Number.isFinite(Number(v)) ? Math.round(Number(v)) : 0);

  return {
    calories: toInt(parsed.calories),
    protein: toInt(parsed.protein),
    carbs: toInt(parsed.carbs),
    fat: toInt(parsed.fat),
    fiber: toInt(parsed.fiber),
    sugar: toInt(parsed.sugar),
  };
});
