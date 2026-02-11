/**
 * One-time script to set up Typesense synonyms server-side.
 * 
 * Migrates all synonym groups from the iOS client's foodSynonyms array
 * into both Typesense collections (foods + foods_ingredients).
 * 
 * Usage:
 *   node setup-synonyms.js
 * 
 * Requires TYPESENSE_ADMIN_API_KEY environment variable.
 */

const axios = require('axios');

const TYPESENSE_CONFIG = {
  host: 'h8ugnjal1c65sm2op-1.a1.typesense.net',
  port: 443,
  protocol: 'https',
  productsCollection: 'foods',
  ingredientsCollection: 'foods_ingredients'
};

// All synonym groups migrated from TypesenseDirectService.swift foodSynonyms array
const SYNONYM_GROUPS = [
  // Proteins
  ["mince", "ground beef", "minced beef", "ground meat"],
  ["prawns", "shrimp", "king prawns"],
  ["gammon", "ham steak"],

  // Vegetables
  ["courgette", "zucchini", "courgettes", "zucchinis"],
  ["aubergine", "eggplant", "aubergines", "eggplants"],
  ["rocket", "arugula", "rocket salad", "arugula salad"],
  ["coriander", "cilantro", "fresh coriander", "fresh cilantro"],
  ["spring onion", "spring onions", "scallion", "scallions", "green onion", "green onions"],
  ["bell pepper", "capsicum", "sweet pepper"],
  ["swede", "rutabaga", "yellow turnip"],
  ["mangetout", "mange tout", "snow peas", "sugar snap peas"],
  ["beetroot", "beet", "beets", "red beet"],
  ["broad beans", "fava beans", "fava"],
  ["sweetcorn", "sweet corn", "corn on the cob"],
  ["chips", "fries", "french fries", "oven chips"],

  // Snacks
  ["crisps", "potato chips", "potato crisps"],
  ["biscuit", "biscuits", "cookie", "cookies"],
  ["sweets", "candy", "candies"],

  // Dairy
  ["single cream", "light cream", "pouring cream"],
  ["double cream", "heavy cream", "heavy whipping cream", "whipping cream"],
  ["full fat milk", "whole milk", "full cream milk"],
  ["semi skimmed", "semi-skimmed milk", "2% milk", "reduced fat milk"],
  ["skimmed milk", "skim milk", "fat free milk", "nonfat milk"],

  // Baking/Pantry
  ["plain flour", "all purpose flour", "all-purpose flour"],
  ["strong flour", "bread flour", "strong bread flour"],
  ["caster sugar", "castor sugar", "superfine sugar"],
  ["icing sugar", "powdered sugar", "confectioners sugar"],
  ["bicarbonate of soda", "bicarb", "baking soda"],
  ["cornflour", "corn flour", "cornstarch", "corn starch"],
  ["treacle", "black treacle", "molasses"],
  ["golden syrup", "light treacle"],

  // Grains
  ["porridge", "porridge oats", "oatmeal", "oat porridge"],
  ["wholemeal", "whole meal", "wholewheat", "whole wheat"],

  // Misc
  ["jam", "fruit preserve", "preserves"],
  ["stock cube", "stock cubes", "bouillon cube", "bouillon"],
  ["tomato puree", "tomato purée", "tomato paste", "tomato concentrate"],
  ["muesli", "granola", "bircher muesli"],
];

async function setupSynonyms() {
  const apiKey = process.env.TYPESENSE_ADMIN_API_KEY;
  if (!apiKey) {
    console.error('❌ Set TYPESENSE_ADMIN_API_KEY environment variable first');
    console.error('   export TYPESENSE_ADMIN_API_KEY=your_key_here');
    process.exit(1);
  }

  const baseUrl = `${TYPESENSE_CONFIG.protocol}://${TYPESENSE_CONFIG.host}:${TYPESENSE_CONFIG.port}`;
  const collections = [TYPESENSE_CONFIG.productsCollection, TYPESENSE_CONFIG.ingredientsCollection];

  let created = 0;
  let errors = 0;

  for (const collection of collections) {
    console.log(`\n📦 Setting up synonyms for collection: ${collection}`);

    for (let i = 0; i < SYNONYM_GROUPS.length; i++) {
      const group = SYNONYM_GROUPS[i];
      const id = `syn_${i}_${group[0].replace(/\s+/g, '_').replace(/[^a-z0-9_]/g, '').toLowerCase()}`;

      try {
        await axios.put(
          `${baseUrl}/collections/${collection}/synonyms/${id}`,
          { synonyms: group },
          {
            headers: {
              'X-TYPESENSE-API-KEY': apiKey,
              'Content-Type': 'application/json'
            },
            timeout: 10000
          }
        );
        console.log(`  ✅ ${id}: ${group.join(' ↔ ')}`);
        created++;
      } catch (err) {
        console.error(`  ❌ ${id}: ${err.response?.data?.message || err.message}`);
        errors++;
      }
    }
  }

  console.log(`\n🏁 Done! Created: ${created}, Errors: ${errors}`);
  console.log(`   Total synonym groups per collection: ${SYNONYM_GROUPS.length}`);
}

setupSynonyms();
