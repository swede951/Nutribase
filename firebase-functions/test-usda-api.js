/**
 * Test USDA FoodData Central API
 * Run with: node test-usda-api.js
 */

const axios = require('axios');

const USDA_API_KEY = 'DEMO_KEY';
const USDA_BASE_URL = 'https://api.nal.usda.gov/fdc/v1';

// Test foods
const testFoods = [
    'Honey',
    'Banana',
    'Chicken breast',
    'Coca Cola',
    'Greek yogurt',
    'Cheddar cheese',
    'Avocado',
    'Cashew nuts',
    'Tuna',
    'Sweet potato',
    'Butter',
    'Eggs',
    'Peanut butter',
    'White rice',
    'Oatmeal'
];

// Real values for comparison
const realValues = {
    'Honey': { sugar: 82, fiber: 0.2 },
    'Banana': { sugar: 12.2, fiber: 2.6 },
    'Chicken breast': { sugar: 0, fiber: 0 },
    'Coca Cola': { sugar: 10.6, fiber: 0 },
    'Greek yogurt': { sugar: 4, fiber: 0 },
    'Cheddar cheese': { sugar: 0.5, fiber: 0 },
    'Avocado': { sugar: 0.7, fiber: 6.7 },
    'Cashew nuts': { sugar: 5.9, fiber: 3.3 },
    'Tuna': { sugar: 0, fiber: 0 },
    'Sweet potato': { sugar: 4.2, fiber: 3 },
    'Butter': { sugar: 0.1, fiber: 0 },
    'Eggs': { sugar: 0.4, fiber: 0 },
    'Peanut butter': { sugar: 6, fiber: 6 },
    'White rice': { sugar: 0.1, fiber: 0.4 },
    'Oatmeal': { sugar: 1, fiber: 10 }
};

// Simplify food name for better USDA matching
function simplifyFoodName(name) {
    // Remove brand names, numbers, percentages
    let simplified = name.toLowerCase()
        .replace(/\d+%/g, '')           // Remove percentages
        .replace(/\d+g/g, '')           // Remove weights
        .replace(/\d+ml/g, '')          // Remove volumes
        .replace(/\s+/g, ' ')           // Normalize spaces
        .trim();
    
    // Map common variations to USDA-friendly terms
    const mappings = {
        'chicken breast': 'chicken, broilers or fryers, breast, meat only, raw',
        'beef mince': 'beef, ground, raw',
        'greek yogurt': 'yogurt, greek',
        'cheddar cheese': 'cheese, cheddar',
        'coca cola': 'cola',
        'peanut butter': 'peanut butter, smooth',
        'white rice': 'rice, white, cooked',
        'oatmeal': 'oats',
        'butter': 'butter, salted',
        'eggs': 'egg, whole, raw',
        'tuna': 'fish, tuna',
        'avocado': 'avocado, raw',
        'cashew nuts': 'nuts, cashew',
        'cashew': 'nuts, cashew',
        'sweet potato': 'sweet potato, raw',
        'olive': 'olives'
    };
    
    // Check for mapping
    for (const [key, value] of Object.entries(mappings)) {
        if (simplified.includes(key)) {
            return value;
        }
    }
    
    return simplified;
}

async function searchUSDA(foodName) {
    const searchQuery = simplifyFoodName(foodName);
    
    try {
        const response = await axios.post(
            `${USDA_BASE_URL}/foods/search?api_key=${USDA_API_KEY}`,
            {
                query: searchQuery,
                dataType: ['Foundation', 'SR Legacy', 'Survey (FNDDS)'],
                pageSize: 10,
                sortBy: 'dataType.keyword',
                sortOrder: 'asc'
            },
            {
                headers: { 'Content-Type': 'application/json' },
                timeout: 10000
            }
        );

        const foods = response.data?.foods || [];
        
        if (foods.length === 0) {
            return { found: false, query: searchQuery };
        }

        // Find best match - prefer Foundation or SR Legacy with matching nutrients
        let bestMatch = null;
        for (const food of foods) {
            // Check if this food has sugar/fiber data
            const hasNutrients = food.foodNutrients?.some(n => 
                n.nutrientName?.toLowerCase().includes('sugar') ||
                n.nutrientName?.toLowerCase().includes('fiber')
            );
            
            if (hasNutrients) {
                if (food.dataType === 'Foundation' || food.dataType === 'SR Legacy') {
                    bestMatch = food;
                    break;
                } else if (!bestMatch) {
                    bestMatch = food;
                }
            }
        }
        
        if (!bestMatch) {
            bestMatch = foods[0];
        }

        // Extract nutrients
        const nutrients = bestMatch.foodNutrients || [];
        let sugar = null;
        let fiber = null;

        for (const nutrient of nutrients) {
            const name = (nutrient.nutrientName || '').toLowerCase();
            if (name.includes('sugar') && sugar === null) {
                sugar = nutrient.value;
            }
            if (name.includes('fiber') && fiber === null) {
                fiber = nutrient.value;
            }
        }

        return {
            found: true,
            match: bestMatch.description,
            dataType: bestMatch.dataType,
            sugar: sugar,
            fiber: fiber,
            query: searchQuery
        };
    } catch (error) {
        return { found: false, error: error.message, query: searchQuery };
    }
}

async function runTest() {
    console.log('\n🔬 USDA FoodData Central API Test');
    console.log('=' .repeat(100));
    console.log('\nSearching USDA database for test foods...\n');

    let totalSugarError = 0;
    let totalFiberError = 0;
    let foundCount = 0;

    console.log('Food'.padEnd(20) + 'USDA Match'.padEnd(35) + 'Sugar'.padStart(8) + 'Real'.padStart(8) + 'Err'.padStart(6) + '  Fiber'.padStart(8) + 'Real'.padStart(8) + 'Err'.padStart(6));
    console.log('-'.repeat(100));

    for (const food of testFoods) {
        const result = await searchUSDA(food);
        const real = realValues[food] || { sugar: 0, fiber: 0 };

        if (result.found && result.sugar !== null) {
            foundCount++;
            const sugarErr = Math.abs((result.sugar || 0) - real.sugar);
            const fiberErr = Math.abs((result.fiber || 0) - real.fiber);
            totalSugarError += sugarErr;
            totalFiberError += fiberErr;

            console.log(
                food.padEnd(20) +
                (result.match || '').substring(0, 33).padEnd(35) +
                (result.sugar?.toFixed(1) || 'N/A').padStart(8) +
                real.sugar.toFixed(1).padStart(8) +
                sugarErr.toFixed(1).padStart(6) +
                (result.fiber?.toFixed(1) || 'N/A').padStart(8) +
                real.fiber.toFixed(1).padStart(8) +
                fiberErr.toFixed(1).padStart(6)
            );
        } else {
            console.log(
                food.padEnd(20) +
                'NOT FOUND'.padEnd(35) +
                'N/A'.padStart(8) +
                real.sugar.toFixed(1).padStart(8) +
                '-'.padStart(6) +
                'N/A'.padStart(8) +
                real.fiber.toFixed(1).padStart(8) +
                '-'.padStart(6)
            );
        }

        // Rate limit delay
        await new Promise(resolve => setTimeout(resolve, 200));
    }

    console.log('-'.repeat(100));
    console.log('\n📊 SUMMARY');
    console.log('=' .repeat(50));
    console.log(`Foods tested: ${testFoods.length}`);
    console.log(`Found in USDA: ${foundCount} (${(foundCount/testFoods.length*100).toFixed(0)}%)`);
    if (foundCount > 0) {
        console.log(`\nUSDA Accuracy (for found foods):`);
        console.log(`  Sugar avg error: ${(totalSugarError / foundCount).toFixed(1)}g`);
        console.log(`  Fiber avg error: ${(totalFiberError / foundCount).toFixed(1)}g`);
    }
    console.log('\n');
}

runTest();
