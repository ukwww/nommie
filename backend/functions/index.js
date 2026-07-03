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
