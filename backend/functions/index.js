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
const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const { defineSecret } = require("firebase-functions/params");
const admin = require("firebase-admin");

if (!admin.apps.length) admin.initializeApp();

const OPENAI_API_KEY = defineSecret("OPENAI_API_KEY");

const ALLOWED_TAGS = [
  "High Protein", "High Fiber", "Low Carb", "Comfort Food", "Light Meal",
  "High Calorie", "Plant-Based", "Baked Good", "Drink/Cocktail",
];

// Notify a user when someone follows them
exports.onFollowCreated = onDocumentCreated("follows/{docId}", async (event) => {
  const data = event.data.data();
  const followerId  = data.followerId;
  const followingId = data.followingId;

  const [followerDoc, followedDoc] = await Promise.all([
    admin.firestore().collection("users").doc(followerId).get(),
    admin.firestore().collection("users").doc(followingId).get(),
  ]);

  const followerUsername = followerDoc.data()?.username ?? "Someone";
  const fcmToken = followedDoc.data()?.fcmToken;
  if (!fcmToken) return;

  await admin.messaging().send({
    token: fcmToken,
    notification: {
      title: "New follower",
      body: `@${followerUsername} started following you.`,
    },
    data: { type: "follow", followerId },
    apns: { payload: { aps: { sound: "default" } } },
  });
});

// Notify the original author when someone replates their recipe
exports.onReplateCreated = onDocumentCreated("recipes/{recipeId}", async (event) => {
  const data = event.data.data();
  if (!data.replateMeta) return;

  const replaterUsername = data.username;
  const originalUserId  = data.replateMeta.originalUserId;
  const originalDishName = data.replateMeta.originalDishName;

  // Don't notify when someone replates their own recipe
  if (data.userId === originalUserId) return;

  const originalUserDoc = await admin.firestore().collection("users").doc(originalUserId).get();
  const fcmToken = originalUserDoc.data()?.fcmToken;
  if (!fcmToken) return;

  await admin.messaging().send({
    token: fcmToken,
    notification: {
      title: "Your recipe was replated",
      body: `@${replaterUsername} cooked your ${originalDishName}.`,
    },
    data: { type: "replate", recipeId: event.params.recipeId },
    apns: { payload: { aps: { sound: "default" } } },
  });
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

  const systemMessage =
    "You are a precise nutrition analyst. " +
    "Use USDA FoodData Central values as your reference where possible. " +
    "When quantities are given (weight, volume, count), use them directly. " +
    "When quantities are vague, assume typical restaurant/home-cooking portion sizes. " +
    "Account for cooking methods that affect macros (e.g., oil absorption when frying, water loss when roasting). " +
    "Never guess wildly — anchor to real nutritional data.";

  const prompt =
    `${dishContext}${servingContext}` +
    `Ingredients (total for the whole recipe): ${ingredients}. ` +
    `Calculate the combined nutritional macros for ALL ingredients together. ` +
    `Return ONLY a JSON object with these exact fields: ` +
    `calories (Int, total kcal), protein (Int, grams), carbs (Int, grams), fat (Int, grams), ` +
    `tags (Array of 1–3 strings chosen ONLY from: ${ALLOWED_TAGS.join(", ")}). ` +
    `No explanation, no markdown, just the raw JSON object.`;

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
        max_tokens: 200,
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
  const tags = Array.isArray(parsed.tags)
    ? parsed.tags.filter((t) => ALLOWED_TAGS.includes(t))
    : [];

  return {
    calories: toInt(parsed.calories),
    protein: toInt(parsed.protein),
    carbs: toInt(parsed.carbs),
    fat: toInt(parsed.fat),
    tags,
  };
});
