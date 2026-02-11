/**
 * Firebase Cloud Functions for Nutribase
 * 
 * Deploy with: firebase deploy --only functions
 */

const functions = require('firebase-functions');
const admin = require('firebase-admin');
const axios = require('axios');

admin.initializeApp();

// API keys from Firebase Secret Manager
const { defineSecret } = require('firebase-functions/params');
const openaiApiKey = defineSecret('OPENAI_API_KEY');
const typesenseAdminKey = defineSecret('TYPESENSE_ADMIN_API_KEY');

// Typesense configuration
const TYPESENSE_CONFIG = {
  host: 'h8ugnjal1c65sm2op-1.a1.typesense.net',
  port: 443,
  protocol: 'https',
  productsCollection: 'foods',
  ingredientsCollection: 'foods_ingredients'
};

/**
 * Submit Food Flag - Secure Cloud Function
 * 
 * This function handles food flag submissions securely without giving
 * users direct write access to Firestore.
 */
exports.submitFoodFlag = functions.https.onCall(async (data, context) => {
  try {
    // Extract data from request
    const {
      userId,
      foodId,
      foodName,
      brand,
      barcode,
      issueType,
      details
    } = data;

    // Validate required fields
    if (!foodId || !foodName || !issueType) {
      throw new functions.https.HttpsError(
        'invalid-argument',
        'Missing required fields: foodId, foodName, or issueType'
      );
    }

    // Validate issue type
    const validIssueTypes = [
      'Incorrect nutrition information',
      'Wrong serving sizes',
      'Duplicate entry',
      'Misleading name or brand',
      'Missing information',
      'Other issue'
    ];

    if (!validIssueTypes.includes(issueType)) {
      throw new functions.https.HttpsError(
        'invalid-argument',
        'Invalid issue type'
      );
    }

    // Rate limiting: Check if user has submitted too many flags recently
    if (userId && userId !== 'anonymous') {
      const recentFlags = await admin.firestore()
        .collection('food_flags')
        .where('userId', '==', userId)
        .where('createdAt', '>', new Date(Date.now() - 24 * 60 * 60 * 1000)) // Last 24 hours
        .get();

      if (recentFlags.size >= 10) {
        throw new functions.https.HttpsError(
          'resource-exhausted',
          'Too many flag submissions. Please try again later.'
        );
      }
    }

    // Create flag document
    const flagData = {
      userId: userId || 'anonymous',
      foodId: foodId,
      foodName: foodName,
      brand: brand || '',
      barcode: barcode || '',
      issueType: issueType,
      details: details || '',
      status: 'pending',
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      reviewedAt: null,
      reviewedBy: null,
      resolutionNotes: null
    };

    // Write to Firestore
    const docRef = await admin.firestore()
      .collection('food_flags')
      .add(flagData);

    console.log(`✅ Food flag created: ${docRef.id}`);
    console.log(`   Food: ${foodName} (${foodId})`);
    console.log(`   Issue: ${issueType}`);
    console.log(`   User: ${userId}`);

    // Optional: Send notification to admin (email, Slack, etc.)
    // await sendAdminNotification(flagData);

    return {
      success: true,
      flagId: docRef.id,
      message: 'Flag submitted successfully'
    };

  } catch (error) {
    console.error('❌ Error submitting food flag:', error);
    
    // Re-throw HttpsError as-is
    if (error instanceof functions.https.HttpsError) {
      throw error;
    }
    
    // Wrap other errors
    throw new functions.https.HttpsError(
      'internal',
      'Failed to submit flag',
      error.message
    );
  }
});

/**
 * Get Flag Statistics - Admin only
 * 
 * Returns statistics about food flags for admin dashboard
 */
exports.getFlagStatistics = functions.https.onCall(async (data, context) => {
  // Check if user is authenticated
  if (!context.auth) {
    throw new functions.https.HttpsError(
      'unauthenticated',
      'User must be authenticated'
    );
  }

  // Optional: Check if user is admin
  // const userDoc = await admin.firestore().collection('users').doc(context.auth.uid).get();
  // if (!userDoc.exists || userDoc.data().role !== 'admin') {
  //   throw new functions.https.HttpsError('permission-denied', 'Admin access required');
  // }

  try {
    const flagsSnapshot = await admin.firestore()
      .collection('food_flags')
      .get();

    const stats = {
      total: 0,
      pending: 0,
      resolved: 0,
      dismissed: 0,
      byIssueType: {}
    };

    flagsSnapshot.forEach(doc => {
      const data = doc.data();
      stats.total++;
      
      const status = data.status || 'pending';
      stats[status] = (stats[status] || 0) + 1;

      const issueType = data.issueType;
      stats.byIssueType[issueType] = (stats.byIssueType[issueType] || 0) + 1;
    });

    return stats;

  } catch (error) {
    console.error('❌ Error getting flag statistics:', error);
    throw new functions.https.HttpsError(
      'internal',
      'Failed to get statistics',
      error.message
    );
  }
});

/**
 * Optional: Send admin notification when flag is submitted
 */
async function sendAdminNotification(flagData) {
  // Example: Send email using SendGrid, Mailgun, etc.
  // Example: Send Slack notification
  // Example: Increment counter in Firestore for admin dashboard
  
  console.log('📧 Admin notification would be sent here');
  // Implementation depends on your preferred notification method
}

/**
 * Scheduled function to send daily digest of pending flags
 * Runs every day at 9 AM
 */
exports.sendDailyFlagDigest = functions.pubsub
  .schedule('0 9 * * *')
  .timeZone('Europe/London')
  .onRun(async (context) => {
    try {
      const pendingFlags = await admin.firestore()
        .collection('food_flags')
        .where('status', '==', 'pending')
        .get();

      if (pendingFlags.empty) {
        console.log('No pending flags to report');
        return null;
      }

      console.log(`📊 Daily digest: ${pendingFlags.size} pending flags`);
      
      // Send email/notification with summary
      // await sendDigestEmail(pendingFlags);

      return null;
    } catch (error) {
      console.error('❌ Error sending daily digest:', error);
      return null;
    }
  });

/**
 * OpenAI Proxy - Secure AI Food Nutrition Lookup
 * 
 * This function proxies requests to OpenAI API, keeping the API key secure
 * on the server side. Requires user authentication.
 */
/**
 * USDA FoodData Central API - Get verified nutritional data
 * 
 * Searches USDA database for similar foods and returns verified sugar/fiber values.
 * This is more accurate than AI estimation for common foods.
 */
exports.usdaNutrientLookup = functions
  .https.onCall(async (data, context) => {
  // Require authentication
  if (!context.auth) {
    throw new functions.https.HttpsError(
      'unauthenticated',
      'User must be authenticated'
    );
  }

  const { foods } = data;

  if (!foods || !Array.isArray(foods) || foods.length === 0) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'Foods array is required'
    );
  }

  if (foods.length > 20) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'Maximum 20 foods per request'
    );
  }

  // USDA API key - using DEMO_KEY for now, should be upgraded to a real key
  // Get a free key at: https://api.data.gov/signup/
  const USDA_API_KEY = 'DEMO_KEY';
  const USDA_BASE_URL = 'https://api.nal.usda.gov/fdc/v1';

  // USDA Nutrient IDs
  const SUGAR_NUTRIENT_ID = 269;  // Sugars, total
  const FIBER_NUTRIENT_ID = 291;  // Fiber, total dietary

  try {
    const results = [];

    for (const food of foods) {
      const foodName = food.name || '';
      
      try {
        // Search USDA for this food
        const searchResponse = await axios.post(
          `${USDA_BASE_URL}/foods/search?api_key=${USDA_API_KEY}`,
          {
            query: foodName,
            dataType: ['Foundation', 'SR Legacy', 'Survey (FNDDS)'], // Prefer standard reference data
            pageSize: 5,
            sortBy: 'dataType.keyword',
            sortOrder: 'asc'
          },
          {
            headers: { 'Content-Type': 'application/json' },
            timeout: 10000
          }
        );

        const searchResults = searchResponse.data?.foods || [];
        
        if (searchResults.length > 0) {
          // Find best match - prefer Foundation or SR Legacy data
          let bestMatch = searchResults[0];
          for (const result of searchResults) {
            if (result.dataType === 'Foundation' || result.dataType === 'SR Legacy') {
              bestMatch = result;
              break;
            }
          }

          // Extract sugar and fiber from nutrients
          const nutrients = bestMatch.foodNutrients || [];
          let sugar = null;
          let fiber = null;

          for (const nutrient of nutrients) {
            if (nutrient.nutrientId === SUGAR_NUTRIENT_ID || 
                nutrient.nutrientName?.toLowerCase().includes('sugar')) {
              sugar = nutrient.value;
            }
            if (nutrient.nutrientId === FIBER_NUTRIENT_ID || 
                nutrient.nutrientName?.toLowerCase().includes('fiber')) {
              fiber = nutrient.value;
            }
          }

          results.push({
            name: foodName,
            usdaMatch: bestMatch.description,
            dataType: bestMatch.dataType,
            sugar: sugar !== null ? sugar : null,
            fiber: fiber !== null ? fiber : null,
            found: true
          });
        } else {
          results.push({
            name: foodName,
            usdaMatch: null,
            sugar: null,
            fiber: null,
            found: false
          });
        }
      } catch (searchError) {
        console.error(`USDA search error for "${foodName}":`, searchError.message);
        results.push({
          name: foodName,
          usdaMatch: null,
          sugar: null,
          fiber: null,
          found: false,
          error: searchError.message
        });
      }

      // Small delay to respect rate limits (1000 req/hour)
      await new Promise(resolve => setTimeout(resolve, 100));
    }

    console.log(`✅ USDA lookup completed for ${foods.length} foods`);

    return {
      success: true,
      results: results
    };

  } catch (error) {
    console.error('❌ USDA lookup error:', error.message);
    throw new functions.https.HttpsError(
      'internal',
      'Failed to lookup USDA data',
      error.message
    );
  }
});

/**
 * AI Nutrient Estimation - Estimate missing sugar/fiber values
 * 
 * Lightweight function for estimating specific nutrients when database values are missing.
 * Used by gut health calculations.
 */
exports.aiNutrientEstimate = functions
  .runWith({ secrets: [openaiApiKey] })
  .https.onCall(async (data, context) => {
  // Require authentication
  if (!context.auth) {
    throw new functions.https.HttpsError(
      'unauthenticated',
      'User must be authenticated to use AI features'
    );
  }

  const apiKey = openaiApiKey.value();
  if (!apiKey) {
    throw new functions.https.HttpsError(
      'failed-precondition',
      'AI service not configured'
    );
  }

  const { foods } = data;

  // Validate input - expect array of foods
  if (!foods || !Array.isArray(foods) || foods.length === 0) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'Foods array is required'
    );
  }

  // Limit batch size
  if (foods.length > 20) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'Maximum 20 foods per request'
    );
  }

  // Rate limiting
  const userId = context.auth.uid;
  const recentRequests = await admin.firestore()
    .collection('ai_nutrient_estimates')
    .where('userId', '==', userId)
    .where('createdAt', '>', new Date(Date.now() - 60 * 60 * 1000))
    .get();

  if (recentRequests.size >= 100) {
    throw new functions.https.HttpsError(
      'resource-exhausted',
      'Too many AI requests. Please try again later.'
    );
  }

  try {
    // Build detailed food list with context
    const foodList = foods.map((f, i) => {
      let desc = `${i + 1}. "${f.name}"`;
      if (f.brand) desc += ` (Brand: ${f.brand})`;
      // Add nutritional context if available to help estimation
      if (f.calories) desc += ` [~${f.calories} kcal/100g]`;
      if (f.carbs) desc += ` [${f.carbs}g carbs/100g]`;
      return desc;
    }).join('\n');

    // Research-backed prompt with structured approach
    const prompt = `You have access to the USDA FoodData Central database. For each food below, provide the sugar and fiber content per 100g.

REFERENCE VALUES (USDA database):
| Food | Sugar (g/100g) | Fiber (g/100g) |
|------|----------------|----------------|
| Raw honey | 82.1 | 0.2 |
| Banana, raw | 12.2 | 2.6 |
| Chicken breast, raw | 0 | 0 |
| Cola beverage | 10.6 | 0 |
| Greek yogurt, plain | 3.6 | 0 |
| Avocado, raw | 0.7 | 6.7 |
| Cheddar cheese | 0.5 | 0 |
| Peanut butter | 6.0 | 6.0 |
| Olive oil | 0 | 0 |
| White rice, cooked | 0.03 | 0.4 |
| Sweet potato, raw | 4.2 | 3.0 |
| Cashew nuts | 5.9 | 3.3 |
| Butter | 0.1 | 0 |

FOODS TO ANALYZE:
${foodList}

ANALYSIS RULES:
1. Values must be per 100g (not per serving)
2. Use the USDA reference values for similar foods
3. Meat/fish/poultry: sugar ≈ 0g, fiber = 0g
4. Eggs: sugar ≈ 0.4g, fiber = 0g  
5. Dairy (milk/yogurt): sugar 3-5g (lactose), fiber = 0g
6. Cheese/butter: sugar 0-1g, fiber = 0g
7. Sweeteners (honey/syrup/jam): sugar 50-82g
8. Sodas/soft drinks: sugar 8-12g
9. Nuts: sugar 2-8g, fiber 3-10g
10. Fresh fruits: sugar 5-15g, fiber 1-4g
11. Vegetables: sugar 1-5g, fiber 1-4g
12. Oils: sugar = 0g, fiber = 0g

Return a JSON object with this exact structure:
{
  "estimates": [
    {"sugar": <number>, "fiber": <number>},
    ...
  ]
}

Provide estimates in the SAME ORDER as the input foods.`;

    console.log(`🤖 AI Nutrient estimate for ${foods.length} foods (User: ${userId})`);

    const response = await axios.post(
      'https://api.openai.com/v1/chat/completions',
      {
        model: 'gpt-4o', // Full model for accuracy
        messages: [
          {
            role: 'system',
            content: `You are a registered dietitian nutritionist (RDN) with 15 years of clinical experience and direct access to the USDA FoodData Central database. Your task is to provide accurate nutritional values per 100g for foods.

IMPORTANT: Research shows AI tends to underestimate nutrients. Be precise and use actual database values, not conservative guesses. If a food contains sugar (like sodas, honey, fruits), report the full amount.`
          },
          {
            role: 'user',
            content: prompt
          }
        ],
        temperature: 0.05, // Very low for consistency
        max_tokens: 1000,
        response_format: { type: 'json_object' }
      },
      {
        headers: {
          'Authorization': `Bearer ${apiKey}`,
          'Content-Type': 'application/json'
        },
        timeout: 25000
      }
    );

    const aiContent = response.data.choices[0]?.message?.content;
    if (!aiContent) {
      throw new Error('Empty response from AI');
    }

    const result = JSON.parse(aiContent);
    let estimates = result.estimates || [];

    // Validate and sanitize AI responses
    estimates = estimates.map((est, idx) => {
      const food = foods[idx];
      const foodName = food?.name?.toLowerCase() || '';
      
      let sugar = typeof est?.sugar === 'number' ? est.sugar : 2.0;
      let fiber = typeof est?.fiber === 'number' ? est.fiber : 2.0;
      
      // Clamp to valid ranges
      sugar = Math.max(0, Math.min(100, sugar));
      fiber = Math.max(0, Math.min(50, fiber));
      
      // Apply common-sense validation rules
      const meatKeywords = ['beef', 'chicken', 'pork', 'lamb', 'fish', 'tuna', 'salmon', 'cod', 'meat', 'steak', 'mince'];
      const isMeat = meatKeywords.some(k => foodName.includes(k));
      if (isMeat) {
        sugar = Math.min(sugar, 1); // Meat has virtually no sugar
        fiber = 0;
      }
      
      const eggKeywords = ['egg'];
      const isEgg = eggKeywords.some(k => foodName.includes(k));
      if (isEgg) {
        sugar = Math.min(sugar, 1);
        fiber = 0;
      }
      
      const dairyKeywords = ['butter', 'cheese', 'cream'];
      const isDairy = dairyKeywords.some(k => foodName.includes(k));
      if (isDairy) {
        sugar = Math.min(sugar, 5);
        fiber = 0;
      }
      
      const sweetenerKeywords = ['honey', 'syrup', 'jam', 'sugar', 'treacle'];
      const isSweetener = sweetenerKeywords.some(k => foodName.includes(k));
      if (isSweetener) {
        sugar = Math.max(sugar, 40); // Sweeteners have high sugar
      }
      
      return { sugar: Math.round(sugar * 10) / 10, fiber: Math.round(fiber * 10) / 10 };
    });

    // Log for tracking
    await admin.firestore().collection('ai_nutrient_estimates').add({
      userId: userId,
      foodCount: foods.length,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      tokensUsed: response.data.usage?.total_tokens || 0
    });

    console.log(`✅ AI Nutrient estimate successful for ${foods.length} foods`);

    return {
      success: true,
      estimates: estimates
    };

  } catch (error) {
    console.error('❌ AI Nutrient estimate error:', error.message);
    throw new functions.https.HttpsError(
      'internal',
      'Failed to estimate nutrients',
      error.message
    );
  }
});

exports.aiNutritionLookup = functions
  .runWith({ secrets: [openaiApiKey] })
  .https.onCall(async (data, context) => {
  // Require authentication
  if (!context.auth) {
    throw new functions.https.HttpsError(
      'unauthenticated',
      'User must be authenticated to use AI features'
    );
  }

  // Get API key from secret
  const apiKey = openaiApiKey.value();
  
  // Validate API key is configured
  if (!apiKey) {
    console.error('❌ OpenAI API key not configured');
    throw new functions.https.HttpsError(
      'failed-precondition',
      'AI service not configured'
    );
  }

  const { foodName, brandName, barcode } = data;

  // Validate input
  if (!foodName || typeof foodName !== 'string' || foodName.trim().length === 0) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'Food name is required'
    );
  }

  // Rate limiting: Check user's recent AI requests
  const userId = context.auth.uid;
  const recentRequests = await admin.firestore()
    .collection('ai_requests')
    .where('userId', '==', userId)
    .where('createdAt', '>', new Date(Date.now() - 60 * 60 * 1000)) // Last hour
    .get();

  if (recentRequests.size >= 50) {
    throw new functions.https.HttpsError(
      'resource-exhausted',
      'Too many AI requests. Please try again later.'
    );
  }

  try {
    // Build the prompt
    let prompt = `Provide nutrition information for: ${foodName.trim()}`;
    if (brandName) prompt += ` (Brand: ${brandName})`;
    if (barcode) prompt += ` (Barcode: ${barcode})`;
    
    prompt += `\n\nReturn a JSON object with these fields (use null if unknown):
{
  "serving_size": number (in grams),
  "serving_unit": string,
  "servings_per_container": number,
  "calories": number,
  "protein": number (grams),
  "carbs": number (grams),
  "fat": number (grams),
  "fiber": number (grams),
  "sugar": number (grams),
  "sodium": number (mg),
  "saturated_fat": number (grams),
  "trans_fat": number (grams),
  "cholesterol": number (mg),
  "potassium": number (mg),
  "calcium": number (mg),
  "iron": number (mg),
  "vitamin_c": number (mg),
  "vitamin_a": number (mcg),
  "ingredients": string (comma-separated list),
  "confidence": "high" | "medium" | "low"
}`;

    console.log(`🤖 AI Nutrition lookup for: ${foodName} (User: ${userId})`);

    // Call OpenAI API
    const response = await axios.post(
      'https://api.openai.com/v1/chat/completions',
      {
        model: 'gpt-4o',
        messages: [
          {
            role: 'system',
            content: 'You are a nutrition database assistant. Return accurate nutrition information in JSON format. All values should be per serving. If uncertain, provide reasonable estimates and set confidence to "low" or "medium".'
          },
          {
            role: 'user',
            content: prompt
          }
        ],
        temperature: 0.3,
        max_tokens: 1000,
        response_format: { type: 'json_object' }
      },
      {
        headers: {
          'Authorization': `Bearer ${apiKey}`,
          'Content-Type': 'application/json'
        },
        timeout: 30000
      }
    );

    // Parse OpenAI response
    const aiContent = response.data.choices[0]?.message?.content;
    if (!aiContent) {
      throw new Error('Empty response from AI');
    }

    const nutritionData = JSON.parse(aiContent);

    // Log the request for analytics/billing tracking
    await admin.firestore().collection('ai_requests').add({
      userId: userId,
      foodName: foodName,
      brandName: brandName || null,
      barcode: barcode || null,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      tokensUsed: response.data.usage?.total_tokens || 0
    });

    console.log(`✅ AI Nutrition lookup successful for: ${foodName}`);

    return {
      success: true,
      data: nutritionData
    };

  } catch (error) {
    console.error('❌ AI Nutrition lookup error:', error.message);

    if (error.response?.status === 429) {
      throw new functions.https.HttpsError(
        'resource-exhausted',
        'AI service is busy. Please try again later.'
      );
    }

    if (error.response?.status === 401) {
      throw new functions.https.HttpsError(
        'internal',
        'AI service configuration error'
      );
    }

    throw new functions.https.HttpsError(
      'internal',
      'Failed to fetch nutrition data',
      error.message
    );
  }
});

// ============================================================================
// TYPESENSE PROXY FUNCTIONS - Secure API key handling
// ============================================================================

/**
 * Typesense Search Proxy - Secure food search
 * 
 * Proxies search requests to Typesense, keeping admin API key secure.
 * Supports multi-collection search for ingredients and products.
 */
exports.typesenseSearch = functions
  .runWith({ secrets: [typesenseAdminKey] })
  .https.onCall(async (data, context) => {
  // Require authentication
  if (!context.auth) {
    throw new functions.https.HttpsError(
      'unauthenticated',
      'User must be authenticated'
    );
  }

  const { query, collection, filters, perPage = 50 } = data;

  if (!query || typeof query !== 'string') {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'Query string is required'
    );
  }

  // Rate limiting: 200 searches per hour per user
  const userId = context.auth.uid;
  const recentSearches = await admin.firestore()
    .collection('search_requests')
    .where('userId', '==', userId)
    .where('createdAt', '>', new Date(Date.now() - 60 * 60 * 1000)) // Last hour
    .get();

  if (recentSearches.size >= 200) {
    throw new functions.https.HttpsError(
      'resource-exhausted',
      'Too many search requests. Please try again later.'
    );
  }

  try {
    const apiKey = typesenseAdminKey.value();
    const targetCollection = collection || TYPESENSE_CONFIG.productsCollection;
    
    const searchUrl = `${TYPESENSE_CONFIG.protocol}://${TYPESENSE_CONFIG.host}:${TYPESENSE_CONFIG.port}/collections/${targetCollection}/documents/search`;

    const searchParams = {
      q: query,
      query_by: 'name,brand,name_norm,brand_norm,ingredients_text',
      query_by_weights: '5,3,4,2,1',
      num_typos: 2,
      typo_tokens_threshold: 3,
      prefix: true,
      prioritize_exact_match: true,
      prioritize_token_position: true,
      per_page: Math.min(perPage, 100), // Cap at 100
      sort_by: '_text_match(buckets:10):desc,popularity:desc,quality_score:desc'
    };

    if (filters) {
      searchParams.filter_by = filters;
    }

    const response = await axios.get(searchUrl, {
      params: searchParams,
      headers: {
        'X-TYPESENSE-API-KEY': apiKey
      },
      timeout: 10000
    });

    console.log(`✅ Typesense search: "${query}" returned ${response.data.found} results`);

    // Log search request for rate limiting (fire and forget)
    admin.firestore().collection('search_requests').add({
      userId: userId,
      query: query.substring(0, 100), // Truncate for storage
      createdAt: admin.firestore.FieldValue.serverTimestamp()
    }).catch(err => console.log('Search log failed:', err.message));

    return {
      success: true,
      found: response.data.found,
      hits: response.data.hits,
      search_time_ms: response.data.search_time_ms
    };

  } catch (error) {
    console.error('❌ Typesense search error:', error.message);
    throw new functions.https.HttpsError(
      'internal',
      'Search failed',
      error.message
    );
  }
});

/**
 * Typesense Multi-Search Proxy - Two-lane search
 * 
 * Performs multi-collection search for ingredients and products simultaneously.
 */
exports.typesenseMultiSearch = functions
  .runWith({ secrets: [typesenseAdminKey] })
  .https.onCall(async (data, context) => {
  // Require authentication
  if (!context.auth) {
    throw new functions.https.HttpsError(
      'unauthenticated',
      'User must be authenticated'
    );
  }

  const { searches } = data;

  if (!searches || !Array.isArray(searches) || searches.length === 0) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'Searches array is required'
    );
  }

  if (searches.length > 10) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'Maximum 10 searches per request'
    );
  }

  try {
    const apiKey = typesenseAdminKey.value();
    const multiSearchUrl = `${TYPESENSE_CONFIG.protocol}://${TYPESENSE_CONFIG.host}:${TYPESENSE_CONFIG.port}/multi_search`;

    const response = await axios.post(
      multiSearchUrl,
      { searches },
      {
        headers: {
          'X-TYPESENSE-API-KEY': apiKey,
          'Content-Type': 'application/json'
        },
        timeout: 15000
      }
    );

    console.log(`✅ Typesense multi-search: ${searches.length} queries completed`);

    return {
      success: true,
      results: response.data.results
    };

  } catch (error) {
    console.error('❌ Typesense multi-search error:', error.message);
    throw new functions.https.HttpsError(
      'internal',
      'Multi-search failed',
      error.message
    );
  }
});

/**
 * Typesense Increment Popularity - Flywheel effect
 * 
 * Increments the popularity counter for a food when user selects it.
 * This makes search improve over time based on real usage.
 */
exports.typesenseIncrementPopularity = functions
  .runWith({ secrets: [typesenseAdminKey] })
  .https.onCall(async (data, context) => {
  // Require authentication
  if (!context.auth) {
    throw new functions.https.HttpsError(
      'unauthenticated',
      'User must be authenticated'
    );
  }

  const { documentId, collection } = data;

  if (!documentId || typeof documentId !== 'string') {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'Document ID is required'
    );
  }

  const targetCollection = collection || TYPESENSE_CONFIG.productsCollection;

  try {
    const apiKey = typesenseAdminKey.value();
    const docUrl = `${TYPESENSE_CONFIG.protocol}://${TYPESENSE_CONFIG.host}:${TYPESENSE_CONFIG.port}/collections/${targetCollection}/documents/${documentId}`;

    // First, get current popularity
    let currentPopularity = 0;
    try {
      const getResponse = await axios.get(docUrl, {
        headers: { 'X-TYPESENSE-API-KEY': apiKey },
        timeout: 5000
      });
      currentPopularity = getResponse.data.popularity || 0;
    } catch (getError) {
      // Document might not exist or popularity field missing - that's ok
      console.log(`Document ${documentId} not found or no popularity field`);
    }

    // Increment and update
    const newPopularity = currentPopularity + 1;
    
    await axios.patch(
      docUrl,
      { popularity: newPopularity },
      {
        headers: {
          'X-TYPESENSE-API-KEY': apiKey,
          'Content-Type': 'application/json'
        },
        timeout: 5000
      }
    );

    console.log(`🔥 Popularity flywheel: ${documentId} → ${newPopularity}`);

    return {
      success: true,
      documentId,
      newPopularity
    };

  } catch (error) {
    // Don't fail the whole request if popularity update fails
    console.error('⚠️ Popularity update failed:', error.message);
    return {
      success: false,
      error: error.message
    };
  }
});

/**
 * Typesense Barcode Lookup - Find food by barcode
 * 
 * Searches for a food item by its barcode (EAN/UPC).
 */
exports.typesenseBarcodeLookup = functions
  .runWith({ secrets: [typesenseAdminKey] })
  .https.onCall(async (data, context) => {
  // Require authentication
  if (!context.auth) {
    throw new functions.https.HttpsError(
      'unauthenticated',
      'User must be authenticated'
    );
  }

  const { barcode } = data;

  if (!barcode || typeof barcode !== 'string') {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'Barcode is required'
    );
  }

  // Validate barcode format (basic check for EAN/UPC)
  const cleanBarcode = barcode.replace(/\D/g, '');
  if (cleanBarcode.length < 8 || cleanBarcode.length > 14) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'Invalid barcode format'
    );
  }

  try {
    const apiKey = typesenseAdminKey.value();
    const searchUrl = `${TYPESENSE_CONFIG.protocol}://${TYPESENSE_CONFIG.host}:${TYPESENSE_CONFIG.port}/collections/${TYPESENSE_CONFIG.productsCollection}/documents/search`;

    const response = await axios.get(searchUrl, {
      params: {
        q: '*',
        filter_by: `barcode:=${cleanBarcode}`,
        per_page: 1
      },
      headers: {
        'X-TYPESENSE-API-KEY': apiKey
      },
      timeout: 5000
    });

    if (response.data.found > 0) {
      console.log(`✅ Barcode lookup: ${cleanBarcode} found`);
      return {
        success: true,
        found: true,
        document: response.data.hits[0].document
      };
    } else {
      console.log(`❌ Barcode lookup: ${cleanBarcode} not found`);
      return {
        success: true,
        found: false,
        document: null
      };
    }

  } catch (error) {
    console.error('❌ Barcode lookup error:', error.message);
    throw new functions.https.HttpsError(
      'internal',
      'Barcode lookup failed',
      error.message
    );
  }
});

// ============================================================================
// TYPESENSE SYNONYM MANAGEMENT - Server-side synonym configuration
// ============================================================================

/**
 * Typesense Manage Synonyms - Create, list, or delete synonym groups
 * 
 * Configures Typesense's native multi-way synonyms so the search engine
 * automatically expands queries server-side (e.g. "mince" also matches "ground beef").
 * This replaces the broken client-side synonym expansion.
 */
exports.typesenseManageSynonyms = functions
  .runWith({ secrets: [typesenseAdminKey] })
  .https.onCall(async (data, context) => {
  // Require authentication
  if (!context.auth) {
    throw new functions.https.HttpsError(
      'unauthenticated',
      'User must be authenticated'
    );
  }

  const { action, collection, synonymId, synonyms } = data;

  if (!action || !['create', 'list', 'delete', 'createBatch'].includes(action)) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'Action must be one of: create, list, delete, createBatch'
    );
  }

  try {
    const apiKey = typesenseAdminKey.value();
    const baseUrl = `${TYPESENSE_CONFIG.protocol}://${TYPESENSE_CONFIG.host}:${TYPESENSE_CONFIG.port}`;

    if (action === 'list') {
      // List all synonyms for a collection
      const targetCollection = collection || TYPESENSE_CONFIG.productsCollection;
      const response = await axios.get(
        `${baseUrl}/collections/${targetCollection}/synonyms`,
        {
          headers: { 'X-TYPESENSE-API-KEY': apiKey },
          timeout: 10000
        }
      );

      console.log(`✅ Listed synonyms for ${targetCollection}: ${response.data.synonyms?.length || 0} groups`);
      return { success: true, synonyms: response.data.synonyms || [] };
    }

    if (action === 'delete') {
      if (!synonymId) {
        throw new functions.https.HttpsError('invalid-argument', 'synonymId is required for delete');
      }

      const targetCollection = collection || TYPESENSE_CONFIG.productsCollection;
      await axios.delete(
        `${baseUrl}/collections/${targetCollection}/synonyms/${synonymId}`,
        {
          headers: { 'X-TYPESENSE-API-KEY': apiKey },
          timeout: 10000
        }
      );

      console.log(`✅ Deleted synonym ${synonymId} from ${targetCollection}`);
      return { success: true, deleted: synonymId };
    }

    if (action === 'create') {
      if (!synonyms || !Array.isArray(synonyms) || synonyms.length < 2) {
        throw new functions.https.HttpsError('invalid-argument', 'synonyms must be an array with at least 2 terms');
      }

      const id = synonymId || `syn_${Date.now()}`;
      const targetCollection = collection || TYPESENSE_CONFIG.productsCollection;

      const response = await axios.put(
        `${baseUrl}/collections/${targetCollection}/synonyms/${id}`,
        { synonyms: synonyms },
        {
          headers: {
            'X-TYPESENSE-API-KEY': apiKey,
            'Content-Type': 'application/json'
          },
          timeout: 10000
        }
      );

      console.log(`✅ Created synonym ${id} in ${targetCollection}: ${synonyms.join(', ')}`);
      return { success: true, id, synonyms };
    }

    if (action === 'createBatch') {
      // Create multiple synonym groups across one or more collections
      if (!data.synonymGroups || !Array.isArray(data.synonymGroups)) {
        throw new functions.https.HttpsError('invalid-argument', 'synonymGroups array is required');
      }

      const collections = data.collections || [
        TYPESENSE_CONFIG.productsCollection,
        TYPESENSE_CONFIG.ingredientsCollection
      ];

      let created = 0;
      let errors = [];

      for (const col of collections) {
        for (let i = 0; i < data.synonymGroups.length; i++) {
          const group = data.synonymGroups[i];
          const id = `syn_${i}_${group[0].replace(/\s+/g, '_').toLowerCase()}`;

          try {
            await axios.put(
              `${baseUrl}/collections/${col}/synonyms/${id}`,
              { synonyms: group },
              {
                headers: {
                  'X-TYPESENSE-API-KEY': apiKey,
                  'Content-Type': 'application/json'
                },
                timeout: 10000
              }
            );
            created++;
          } catch (err) {
            errors.push(`${col}/${id}: ${err.message}`);
          }
        }
      }

      console.log(`✅ Batch synonym creation: ${created} created, ${errors.length} errors`);
      return { success: true, created, errors };
    }

  } catch (error) {
    console.error('❌ Synonym management error:', error.message);
    throw new functions.https.HttpsError(
      'internal',
      'Synonym management failed',
      error.message
    );
  }
});
