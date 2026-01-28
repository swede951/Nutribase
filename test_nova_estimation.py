#!/usr/bin/env python3
"""
Comprehensive NOVA estimation test suite (100 test cases)
Uses string[] format for ingredients/categories (matching Typesense schema)
"""

from data_cleaning import NovaEstimator, FoodDataCleaner

# =============================================================================
# 100 TEST CASES FOR NOVA ESTIMATION
# =============================================================================

test_cases = [
    # =========================================================================
    # NOVA 1: UNPROCESSED/MINIMALLY PROCESSED FOODS (Tests 1-25)
    # =========================================================================
    
    # Fresh meats (unbranded)
    {'name': 'Test 1: Chicken breast - unbranded', 'doc': {'name': 'Chicken breast', 'brand': None, 'ingredients': ['chicken breast'], 'nova_score': None}, 'expected': 1},
    {'name': 'Test 2: Beef mince - unbranded', 'doc': {'name': 'Beef mince', 'brand': None, 'ingredients': ['beef'], 'nova_score': None}, 'expected': 1},
    {'name': 'Test 3: Pork loin - unbranded', 'doc': {'name': 'Pork loin', 'brand': None, 'ingredients': ['pork'], 'nova_score': None}, 'expected': 1},
    {'name': 'Test 4: Turkey breast - unbranded', 'doc': {'name': 'Turkey breast', 'brand': None, 'ingredients': ['turkey'], 'nova_score': None}, 'expected': 1},
    {'name': 'Test 5: Lamb chops - unbranded', 'doc': {'name': 'Lamb chops', 'brand': None, 'ingredients': ['lamb'], 'nova_score': None}, 'expected': 1},
    
    # Fresh meats (branded - FIX #2)
    {'name': 'Test 6: Chicken breast - Tesco branded', 'doc': {'name': 'Chicken breast', 'brand': 'Tesco', 'ingredients': ['chicken breast'], 'nova_score': None}, 'expected': 1},
    {'name': 'Test 7: Beef steak - Sainsburys branded', 'doc': {'name': 'Beef steak', 'brand': 'Sainsburys', 'ingredients': ['beef'], 'nova_score': None}, 'expected': 1},
    
    # Fresh fish
    {'name': 'Test 8: Salmon fillet - unbranded', 'doc': {'name': 'Salmon fillet', 'brand': None, 'ingredients': ['salmon'], 'nova_score': None}, 'expected': 1},
    {'name': 'Test 9: Cod fillet - branded', 'doc': {'name': 'Cod fillet', 'brand': 'Birds Eye', 'ingredients': ['cod'], 'nova_score': None}, 'expected': 1},
    {'name': 'Test 10: Tuna steak', 'doc': {'name': 'Tuna steak', 'brand': None, 'ingredients': ['tuna'], 'nova_score': None}, 'expected': 1},
    
    # Eggs and dairy (plain)
    {'name': 'Test 11: Free range eggs', 'doc': {'name': 'Free range eggs', 'brand': None, 'ingredients': ['eggs'], 'nova_score': None}, 'expected': 1},
    {'name': 'Test 12: Whole milk', 'doc': {'name': 'Whole milk', 'brand': 'Cravendale', 'ingredients': ['whole milk'], 'nova_score': None}, 'expected': 1},
    {'name': 'Test 13: Plain Greek yogurt (milk + cultures)', 'doc': {'name': 'Greek yogurt', 'brand': 'Fage', 'ingredients': ['pasteurized milk', 'live yogurt cultures'], 'nova_score': None}, 'expected': 1},
    
    # Fresh fruits and vegetables (no ingredients - name only)
    {'name': 'Test 14: Banana - no ingredients', 'doc': {'name': 'Banana', 'brand': None, 'ingredients': [], 'nova_score': None}, 'expected': 1},
    {'name': 'Test 15: Apple - no ingredients', 'doc': {'name': 'Apple', 'brand': None, 'ingredients': [], 'nova_score': None}, 'expected': 1},
    {'name': 'Test 16: Orange - no ingredients', 'doc': {'name': 'Orange', 'brand': None, 'ingredients': [], 'nova_score': None}, 'expected': 1},
    {'name': 'Test 17: Tomato - no ingredients', 'doc': {'name': 'Tomato', 'brand': None, 'ingredients': [], 'nova_score': None}, 'expected': 1},
    {'name': 'Test 18: Potato - no ingredients', 'doc': {'name': 'Potato', 'brand': None, 'ingredients': [], 'nova_score': None}, 'expected': 1},
    {'name': 'Test 19: Carrot - no ingredients', 'doc': {'name': 'Carrot', 'brand': None, 'ingredients': [], 'nova_score': None}, 'expected': 1},
    {'name': 'Test 20: Broccoli - no ingredients', 'doc': {'name': 'Broccoli', 'brand': None, 'ingredients': [], 'nova_score': None}, 'expected': 1},
    {'name': 'Test 21: Spinach - no ingredients', 'doc': {'name': 'Spinach', 'brand': None, 'ingredients': [], 'nova_score': None}, 'expected': 1},
    
    # Grains and legumes (plain)
    {'name': 'Test 22: Oats', 'doc': {'name': 'Oats', 'brand': None, 'ingredients': ['oats'], 'nova_score': None}, 'expected': 1},
    {'name': 'Test 23: Rice', 'doc': {'name': 'Rice', 'brand': None, 'ingredients': ['rice'], 'nova_score': None}, 'expected': 1},
    {'name': 'Test 24: Quinoa', 'doc': {'name': 'Quinoa', 'brand': None, 'ingredients': ['quinoa'], 'nova_score': None}, 'expected': 1},
    {'name': 'Test 25: Dried lentils', 'doc': {'name': 'Dried lentils', 'brand': None, 'ingredients': ['lentils'], 'nova_score': None}, 'expected': 1},

    # =========================================================================
    # NOVA 2: CULINARY INGREDIENTS (Tests 26-40)
    # =========================================================================
    
    # Oils
    {'name': 'Test 26: Extra virgin olive oil', 'doc': {'name': 'Extra virgin olive oil', 'brand': None, 'ingredients': ['olive oil'], 'nova_score': None}, 'expected': 2},
    {'name': 'Test 27: Olive oil - branded', 'doc': {'name': 'Olive oil', 'brand': 'Filippo Berio', 'ingredients': ['olive oil'], 'nova_score': None}, 'expected': 2},
    {'name': 'Test 28: Vegetable oil', 'doc': {'name': 'Vegetable oil', 'brand': None, 'ingredients': ['rapeseed oil'], 'nova_score': None}, 'expected': 2},
    {'name': 'Test 29: Coconut oil', 'doc': {'name': 'Coconut oil', 'brand': None, 'ingredients': ['coconut oil'], 'nova_score': None}, 'expected': 2},
    {'name': 'Test 30: Sunflower oil', 'doc': {'name': 'Sunflower oil', 'brand': None, 'ingredients': ['sunflower oil'], 'nova_score': None}, 'expected': 2},
    
    # Fats
    {'name': 'Test 31: Butter', 'doc': {'name': 'Butter', 'brand': None, 'ingredients': ['cream', 'salt'], 'nova_score': None}, 'expected': 2},
    {'name': 'Test 32: Ghee', 'doc': {'name': 'Ghee', 'brand': None, 'ingredients': ['butter'], 'nova_score': None}, 'expected': 2},
    
    # Sugars
    {'name': 'Test 33: Caster sugar', 'doc': {'name': 'Caster sugar', 'brand': None, 'ingredients': ['sugar'], 'nova_score': None}, 'expected': 2},
    {'name': 'Test 34: Brown sugar', 'doc': {'name': 'Brown sugar', 'brand': None, 'ingredients': ['sugar', 'molasses'], 'nova_score': None}, 'expected': 2},
    {'name': 'Test 35: Honey', 'doc': {'name': 'Honey', 'brand': None, 'ingredients': ['honey'], 'nova_score': None}, 'expected': 2},
    {'name': 'Test 36: Maple syrup', 'doc': {'name': 'Maple syrup', 'brand': None, 'ingredients': ['maple syrup'], 'nova_score': None}, 'expected': 2},
    
    # Salt and seasonings
    {'name': 'Test 37: Sea salt', 'doc': {'name': 'Sea salt', 'brand': None, 'ingredients': ['sea salt'], 'nova_score': None}, 'expected': 2},
    {'name': 'Test 38: Table salt', 'doc': {'name': 'Table salt', 'brand': None, 'ingredients': ['salt'], 'nova_score': None}, 'expected': 2},
    
    # Flours
    {'name': 'Test 39: Plain flour', 'doc': {'name': 'Plain flour', 'brand': None, 'ingredients': ['wheat flour'], 'nova_score': None}, 'expected': 2},
    {'name': 'Test 40: Self-raising flour', 'doc': {'name': 'Self-raising flour', 'brand': None, 'ingredients': ['wheat flour', 'raising agents'], 'nova_score': None}, 'expected': 2},

    # =========================================================================
    # NOVA 3: PROCESSED FOODS (Tests 41-60)
    # =========================================================================
    
    # Canned goods
    {'name': 'Test 41: Canned kidney beans', 'doc': {'name': 'Canned kidney beans', 'brand': 'Tesco', 'ingredients': ['kidney beans', 'water', 'salt'], 'categories': ['legumes', 'canned foods'], 'nova_score': None}, 'expected': 3},
    {'name': 'Test 42: Canned chickpeas', 'doc': {'name': 'Canned chickpeas', 'brand': 'Napolina', 'ingredients': ['chickpeas', 'water', 'salt'], 'nova_score': None}, 'expected': 3},
    {'name': 'Test 43: Canned tomatoes', 'doc': {'name': 'Chopped tomatoes', 'brand': 'Mutti', 'ingredients': ['tomatoes', 'tomato juice', 'citric acid'], 'nova_score': None}, 'expected': 3},
    {'name': 'Test 44: Canned tuna in water', 'doc': {'name': 'Tuna chunks in spring water', 'brand': 'John West', 'ingredients': ['tuna', 'spring water', 'salt'], 'nova_score': None}, 'expected': 3},
    
    # Breads and baked goods (traditional)
    {'name': 'Test 45: Wholemeal bread', 'doc': {'name': 'Wholemeal bread', 'brand': 'Hovis', 'ingredients': ['wholemeal wheat flour', 'water', 'yeast', 'salt', 'wheat gluten'], 'nova_score': None}, 'expected': 3},
    {'name': 'Test 46: Sourdough bread', 'doc': {'name': 'Sourdough bread', 'brand': 'Gail\'s', 'ingredients': ['wheat flour', 'water', 'salt', 'sourdough culture'], 'nova_score': None}, 'expected': 3},
    {'name': 'Test 47: Pitta bread', 'doc': {'name': 'Pitta bread', 'brand': 'Warburtons', 'ingredients': ['wheat flour', 'water', 'yeast', 'salt', 'sugar'], 'nova_score': None}, 'expected': 3},
    
    # Cheeses
    {'name': 'Test 48: Cheddar cheese', 'doc': {'name': 'Cheddar cheese', 'brand': 'Cathedral City', 'ingredients': ['milk', 'salt', 'rennet', 'cultures'], 'nova_score': None}, 'expected': 3},
    {'name': 'Test 49: Mozzarella', 'doc': {'name': 'Mozzarella', 'brand': 'Galbani', 'ingredients': ['milk', 'salt', 'rennet'], 'nova_score': None}, 'expected': 3},
    {'name': 'Test 50: Parmesan', 'doc': {'name': 'Parmesan', 'brand': 'Parmigiano Reggiano', 'ingredients': ['milk', 'salt', 'rennet'], 'nova_score': None}, 'expected': 3},
    
    # Preserved meats (traditional)
    {'name': 'Test 51: Smoked salmon', 'doc': {'name': 'Smoked salmon', 'brand': 'Tesco Finest', 'ingredients': ['salmon', 'salt', 'sugar'], 'nova_score': None}, 'expected': 3},
    {'name': 'Test 52: Prosciutto', 'doc': {'name': 'Prosciutto', 'brand': 'Parma', 'ingredients': ['pork', 'salt'], 'nova_score': None}, 'expected': 3},
    
    # Fermented foods
    {'name': 'Test 53: Greek yogurt with sugar', 'doc': {'name': 'Greek yogurt', 'brand': 'Chobani', 'ingredients': ['milk', 'live yogurt cultures', 'sugar'], 'nova_score': None}, 'expected': 3},
    {'name': 'Test 54: Sauerkraut', 'doc': {'name': 'Sauerkraut', 'brand': 'Krakus', 'ingredients': ['cabbage', 'salt', 'water'], 'nova_score': None}, 'expected': 3},
    {'name': 'Test 55: Kimchi', 'doc': {'name': 'Kimchi', 'brand': 'Jongga', 'ingredients': ['napa cabbage', 'radish', 'salt', 'gochugaru', 'garlic', 'ginger'], 'nova_score': None}, 'expected': 3},
    
    # Simple preserved/jarred items
    {'name': 'Test 56: Pickled gherkins', 'doc': {'name': 'Pickled gherkins', 'brand': 'Kuhne', 'ingredients': ['gherkins', 'water', 'vinegar', 'salt', 'sugar', 'dill'], 'nova_score': None}, 'expected': 3},
    {'name': 'Test 57: Olives in brine', 'doc': {'name': 'Green olives', 'brand': 'Fragata', 'ingredients': ['olives', 'water', 'salt'], 'nova_score': None}, 'expected': 3},
    
    # Rice cakes (processed but no additives - FIX #4)
    {'name': 'Test 58: Plain rice cakes (snacks category alone)', 'doc': {'name': 'Rice cakes', 'brand': 'Kallo', 'ingredients': ['wholegrain rice', 'salt'], 'categories': ['snacks', 'rice cakes'], 'nova_score': None}, 'expected': 3},
    
    # Pasta
    {'name': 'Test 59: Dried pasta', 'doc': {'name': 'Spaghetti', 'brand': 'De Cecco', 'ingredients': ['durum wheat semolina', 'water'], 'nova_score': None}, 'expected': 3},
    {'name': 'Test 60: Egg pasta', 'doc': {'name': 'Tagliatelle', 'brand': 'Napolina', 'ingredients': ['durum wheat semolina', 'eggs'], 'nova_score': None}, 'expected': 3},

    # =========================================================================
    # NOVA 4: ULTRA-PROCESSED FOODS (Tests 61-100)
    # =========================================================================
    
    # Products with modified starch
    {'name': 'Test 61: Sweet chilli sauce (modified starch)', 'doc': {'name': 'Sweet chilli sauce', 'brand': 'Sainsbury\'s', 'ingredients': ['water', 'sugar', 'red chilli peppers', 'spirit vinegar', 'modified maize starch', 'salt', 'garlic purée', 'stabiliser (xanthan gum)', 'colour (paprika extract)'], 'categories': ['sauces', 'condiments'], 'nova_score': None}, 'expected': 4},
    {'name': 'Test 62: Gravy granules', 'doc': {'name': 'Gravy granules', 'brand': 'Bisto', 'ingredients': ['potato starch', 'maltodextrin', 'salt', 'palm oil', 'colour (E150c)', 'flavourings'], 'nova_score': None}, 'expected': 4},
    
    # Products with E-numbers
    {'name': 'Test 63: Crisps with E-numbers', 'doc': {'name': 'Cheese flavoured crisps', 'brand': 'Walkers', 'ingredients': ['potatoes', 'vegetable oils', 'cheese powder', 'flavourings', 'maltodextrin', 'emulsifiers (E471, E472e)', 'flavour enhancers (monosodium glutamate)', 'colours (E160c)'], 'categories': ['snacks', 'crisps'], 'nova_score': None}, 'expected': 4},
    {'name': 'Test 64: Soft drink with E-numbers', 'doc': {'name': 'Orange soda', 'brand': 'Fanta', 'ingredients': ['carbonated water', 'sugar', 'orange juice', 'citric acid', 'sweeteners (aspartame, acesulfame k)', 'preservative (E211)', 'colour (E160a)'], 'categories': ['soft drinks'], 'nova_score': None}, 'expected': 4},
    
    # Products with protein isolates
    {'name': 'Test 65: Protein shake', 'doc': {'name': 'Protein shake', 'brand': 'MyProtein', 'ingredients': ['whey protein isolate', 'maltodextrin', 'flavourings', 'sucralose', 'emulsifier (soy lecithin)'], 'categories': ['protein supplements'], 'nova_score': None}, 'expected': 4},
    {'name': 'Test 66: High protein yogurt', 'doc': {'name': 'High protein Greek yogurt', 'brand': 'Arla', 'ingredients': ['skimmed milk', 'milk protein concentrate', 'yogurt cultures', 'sweetener (sucralose)'], 'categories': ['high protein yogurt'], 'nova_score': None}, 'expected': 4},
    {'name': 'Test 67: Protein bar', 'doc': {'name': 'Protein bar', 'brand': 'Grenade', 'ingredients': ['protein blend (milk protein, whey protein isolate)', 'glycerine', 'chocolate coating', 'maltitol syrup', 'flavourings'], 'nova_score': None}, 'expected': 4},
    
    # Strong UPF categories
    {'name': 'Test 68: Ice cream', 'doc': {'name': 'Vanilla ice cream', 'brand': 'Ben & Jerry\'s', 'ingredients': ['cream', 'skim milk', 'sugar', 'water', 'glucose syrup', 'vanilla extract', 'stabilisers (guar gum, carrageenan)'], 'categories': ['ice cream', 'frozen desserts'], 'nova_score': None}, 'expected': 4},
    {'name': 'Test 69: Energy drink', 'doc': {'name': 'Energy drink', 'brand': 'Red Bull', 'ingredients': ['water', 'sucrose', 'glucose', 'citric acid', 'taurine', 'sodium bicarbonate', 'caffeine', 'vitamins'], 'categories': ['energy drinks', 'beverages'], 'nova_score': None}, 'expected': 4},
    {'name': 'Test 70: Instant noodles', 'doc': {'name': 'Instant noodles', 'brand': 'Pot Noodle', 'ingredients': ['wheat flour', 'palm oil', 'salt', 'sugar', 'flavourings', 'monosodium glutamate', 'maltodextrin'], 'categories': ['instant noodles'], 'nova_score': None}, 'expected': 4},
    {'name': 'Test 71: Breakfast cereal', 'doc': {'name': 'Frosted flakes', 'brand': 'Kelloggs', 'ingredients': ['maize', 'sugar', 'barley malt extract', 'salt', 'vitamins'], 'categories': ['breakfast cereals'], 'nova_score': None}, 'expected': 4},
    {'name': 'Test 72: Ready meal', 'doc': {'name': 'Chicken tikka masala', 'brand': 'Tesco', 'ingredients': ['chicken', 'rice', 'tomatoes', 'cream', 'onions', 'modified starch', 'flavourings', 'colour'], 'categories': ['ready meals'], 'nova_score': None}, 'expected': 4},
    
    # Flavoured yogurts with additives
    {'name': 'Test 73: Strawberry yogurt with additives', 'doc': {'name': 'Strawberry Greek yogurt', 'brand': 'Muller', 'ingredients': ['milk', 'yogurt cultures', 'sugar', 'strawberries', 'modified starch', 'natural flavourings', 'stabiliser (pectin)'], 'nova_score': None}, 'expected': 4},
    
    # Mayonnaise and sauces with stabilisers (FIX #3 - guard against "oil" match)
    {'name': 'Test 74: Olive oil mayonnaise (stabiliser + many ingredients)', 'doc': {'name': 'Olive oil mayonnaise', 'brand': 'Hellmanns', 'ingredients': ['rapeseed oil', 'water', 'olive oil', 'egg yolk', 'vinegar', 'sugar', 'salt', 'lemon juice', 'stabiliser'], 'nova_score': None}, 'expected': 4},
    {'name': 'Test 75: Ketchup', 'doc': {'name': 'Tomato ketchup', 'brand': 'Heinz', 'ingredients': ['tomatoes', 'sugar', 'vinegar', 'salt', 'onion powder', 'natural flavourings'], 'nova_score': None}, 'expected': 4},
    
    # Snacks + additives (FIX #4 - weak category + additive)
    {'name': 'Test 76: Flavoured rice cakes', 'doc': {'name': 'Flavoured rice cakes', 'brand': 'Kallo', 'ingredients': ['wholegrain rice', 'salt', 'flavourings'], 'categories': ['snacks', 'rice cakes'], 'nova_score': None}, 'expected': 4},
    
    # Sweeteners
    {'name': 'Test 77: Diet cola with sweeteners', 'doc': {'name': 'Diet cola', 'brand': 'Coca Cola', 'ingredients': ['carbonated water', 'caramel colour', 'phosphoric acid', 'sweeteners (aspartame, acesulfame k)', 'natural flavourings', 'caffeine'], 'categories': ['soft drinks'], 'nova_score': None}, 'expected': 4},
    
    # Industrial fats
    {'name': 'Test 78: Margarine with hydrogenated oil', 'doc': {'name': 'Margarine', 'brand': 'Stork', 'ingredients': ['vegetable oils', 'water', 'salt', 'emulsifier (mono- and diglycerides)', 'flavourings', 'colour'], 'nova_score': None}, 'expected': 4},
    
    # Confectionery
    {'name': 'Test 79: Chocolate bar', 'doc': {'name': 'Milk chocolate', 'brand': 'Cadbury', 'ingredients': ['sugar', 'cocoa butter', 'cocoa mass', 'milk', 'vegetable fats', 'emulsifier (E442)', 'flavourings'], 'categories': ['chocolate bars', 'confectionery'], 'nova_score': None}, 'expected': 4},
    {'name': 'Test 80: Gummy sweets', 'doc': {'name': 'Gummy bears', 'brand': 'Haribo', 'ingredients': ['glucose syrup', 'sugar', 'gelatine', 'dextrose', 'fruit juice concentrates', 'citric acid', 'flavourings', 'colours (E100, E120)'], 'categories': ['sweets', 'confectionery'], 'nova_score': None}, 'expected': 4},
    
    # Processed meats
    {'name': 'Test 81: Hot dogs', 'doc': {'name': 'Hot dogs', 'brand': 'Oscar Mayer', 'ingredients': ['pork', 'water', 'salt', 'dextrose', 'sodium phosphates', 'sodium erythorbate', 'sodium nitrite', 'flavourings'], 'nova_score': None}, 'expected': 4},
    {'name': 'Test 82: Chicken nuggets', 'doc': {'name': 'Chicken nuggets', 'brand': 'Birds Eye', 'ingredients': ['chicken breast', 'water', 'wheat flour', 'vegetable oil', 'starch', 'salt', 'yeast extract', 'dextrose', 'flavourings'], 'categories': ['nuggets', 'frozen foods'], 'nova_score': None}, 'expected': 4},
    {'name': 'Test 83: Fish fingers', 'doc': {'name': 'Fish fingers', 'brand': 'Birds Eye', 'ingredients': ['cod fillet', 'breadcrumbs', 'vegetable oil', 'wheat flour', 'salt', 'yeast', 'turmeric'], 'categories': ['fish fingers'], 'nova_score': None}, 'expected': 4},
    
    # Biscuits and cookies
    {'name': 'Test 84: Digestive biscuits', 'doc': {'name': 'Digestive biscuits', 'brand': 'McVities', 'ingredients': ['wheat flour', 'sugar', 'vegetable oil', 'wholemeal wheat flour', 'raising agents', 'salt'], 'categories': ['biscuits'], 'nova_score': None}, 'expected': 4},
    {'name': 'Test 85: Chocolate chip cookies', 'doc': {'name': 'Chocolate chip cookies', 'brand': 'Maryland', 'ingredients': ['wheat flour', 'sugar', 'vegetable oil', 'chocolate chips', 'glucose syrup', 'raising agents', 'salt', 'flavourings'], 'categories': ['cookies', 'biscuits'], 'nova_score': None}, 'expected': 4},
    
    # Breakfast items
    {'name': 'Test 86: Cereal bar', 'doc': {'name': 'Cereal bar', 'brand': 'Nature Valley', 'ingredients': ['oats', 'sugar', 'vegetable oil', 'honey', 'rice flour', 'salt', 'glucose syrup'], 'categories': ['cereal bars'], 'nova_score': None}, 'expected': 4},
    
    # Spreads
    {'name': 'Test 87: Chocolate spread', 'doc': {'name': 'Chocolate hazelnut spread', 'brand': 'Nutella', 'ingredients': ['sugar', 'palm oil', 'hazelnuts', 'cocoa', 'skimmed milk powder', 'whey powder', 'lecithin', 'vanillin'], 'nova_score': None}, 'expected': 4},
    {'name': 'Test 88: Peanut butter with additives', 'doc': {'name': 'Smooth peanut butter', 'brand': 'Skippy', 'ingredients': ['roasted peanuts', 'sugar', 'hydrogenated vegetable oils', 'salt'], 'nova_score': None}, 'expected': 4},
    
    # Frozen desserts
    {'name': 'Test 89: Frozen yogurt', 'doc': {'name': 'Frozen yogurt', 'brand': 'Yeo Valley', 'ingredients': ['skimmed milk', 'sugar', 'cream', 'glucose syrup', 'milk protein', 'stabilisers (locust bean gum, guar gum)'], 'categories': ['frozen desserts'], 'nova_score': None}, 'expected': 4},
    
    # Plant-based UPFs
    {'name': 'Test 90: Vegan burger', 'doc': {'name': 'Vegan burger', 'brand': 'Beyond Meat', 'ingredients': ['water', 'pea protein isolate', 'expeller-pressed canola oil', 'refined coconut oil', 'rice protein', 'natural flavors', 'methylcellulose'], 'nova_score': None}, 'expected': 4},
    {'name': 'Test 91: Oat milk with additives', 'doc': {'name': 'Oat milk', 'brand': 'Oatly', 'ingredients': ['water', 'oats', 'rapeseed oil', 'calcium carbonate', 'calcium phosphates', 'salt', 'vitamins'], 'nova_score': None}, 'expected': 4},
    
    # Sauces with multiple additives
    {'name': 'Test 92: BBQ sauce', 'doc': {'name': 'BBQ sauce', 'brand': 'HP', 'ingredients': ['tomatoes', 'molasses', 'sugar', 'vinegar', 'modified cornflour', 'salt', 'spices', 'flavourings', 'preservatives'], 'nova_score': None}, 'expected': 4},
    {'name': 'Test 93: Salad dressing', 'doc': {'name': 'Caesar dressing', 'brand': 'Newman\'s Own', 'ingredients': ['soybean oil', 'water', 'parmesan cheese', 'egg yolk', 'vinegar', 'salt', 'sugar', 'garlic', 'xanthan gum', 'natural flavors'], 'nova_score': None}, 'expected': 4},
    
    # Canned soups with additives
    {'name': 'Test 94: Cream of tomato soup', 'doc': {'name': 'Cream of tomato soup', 'brand': 'Heinz', 'ingredients': ['tomatoes', 'water', 'sugar', 'modified cornflour', 'cream', 'salt', 'milk proteins', 'flavourings'], 'nova_score': None}, 'expected': 4},
    
    # =========================================================================
    # SPECIAL CASES: OFF source data (Tests 95-100)
    # =========================================================================
    
    {'name': 'Test 95: Product with real NOVA 1 from OFF', 'doc': {'name': 'Fresh chicken', 'brand': 'Tesco', 'ingredients': ['chicken'], 'nova_score': 1}, 'expected_source': 'off'},
    {'name': 'Test 96: Product with real NOVA 2 from OFF', 'doc': {'name': 'Olive oil', 'brand': 'Bertolli', 'ingredients': ['olive oil'], 'nova_score': 2}, 'expected_source': 'off'},
    {'name': 'Test 97: Product with real NOVA 3 from OFF', 'doc': {'name': 'Cheddar cheese', 'brand': 'Cathedral City', 'ingredients': ['milk', 'salt', 'rennet'], 'nova_score': 3}, 'expected_source': 'off'},
    {'name': 'Test 98: Product with real NOVA 4 from OFF', 'doc': {'name': 'Crisps', 'brand': 'Walkers', 'ingredients': ['potatoes', 'oil', 'flavourings'], 'nova_score': 4}, 'expected_source': 'off'},
    {'name': 'Test 99: Product with NOVA score 0 (invalid, should estimate)', 'doc': {'name': 'Apple', 'brand': None, 'ingredients': [], 'nova_score': 0}, 'expected': 1},
    {'name': 'Test 100: Product with no ingredients and generic name (unknown)', 'doc': {'name': 'Mystery food', 'brand': 'Unknown', 'ingredients': [], 'nova_score': None}, 'expected_source': 'unknown'},
]

def run_tests():
    print("🧪 Testing NOVA Estimator\n")
    print("=" * 80)
    
    passed = 0
    failed = 0
    
    for test in test_cases:
        print(f"\n{test['name']}")
        print("-" * 80)
        
        doc = test['doc']
        nova_estimated, nova_source, nova_confidence = NovaEstimator.estimate_nova(doc)
        
        print(f"📋 Input:")
        print(f"   Name: {doc.get('name')}")
        print(f"   Brand: {doc.get('brand')}")
        print(f"   Ingredients: {doc.get('ingredients_text', 'N/A')[:80]}...")
        print(f"   Categories: {doc.get('categories', 'N/A')}")
        print(f"   Existing NOVA: {doc.get('nova_score', 'None')}")
        
        print(f"\n📊 Result:")
        print(f"   NOVA Estimated: {nova_estimated}")
        print(f"   NOVA Source: {nova_source}")
        print(f"   Confidence: {nova_confidence:.2f}")
        
        # Check if test passes
        if 'expected_source' in test:
            # Testing that real NOVA scores are preserved
            if nova_source == test['expected_source']:
                print(f"   ✅ PASS - Source correctly identified as '{nova_source}'")
                passed += 1
            else:
                print(f"   ❌ FAIL - Expected source '{test['expected_source']}', got '{nova_source}'")
                failed += 1
        elif 'expected' in test:
            if nova_estimated == test['expected']:
                print(f"   ✅ PASS - Correctly estimated as NOVA {nova_estimated}")
                passed += 1
            else:
                print(f"   ❌ FAIL - Expected NOVA {test['expected']}, got {nova_estimated}")
                failed += 1
        
        print("=" * 80)
    
    print(f"\n📈 Test Results:")
    print(f"   Passed: {passed}/{len(test_cases)}")
    print(f"   Failed: {failed}/{len(test_cases)}")
    print(f"   Success Rate: {(passed/len(test_cases)*100):.1f}%")
    
    return failed == 0

if __name__ == '__main__':
    success = run_tests()
    exit(0 if success else 1)
