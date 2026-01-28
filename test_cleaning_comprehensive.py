#!/usr/bin/env python3
"""
Comprehensive test suite for data cleaning pipeline
Tests all 9 bug fixes
"""

from data_cleaning import FoodDataCleaner

def test_bug_fixes():
    """Test all 9 critical bug fixes"""
    
    print("=" * 80)
    print("COMPREHENSIVE BUG FIX TESTS")
    print("=" * 80)
    
    # Bug 1: 0-calorie foods (Coke Zero should not be penalized)
    print("\n🧪 BUG 1: Zero-calorie foods should be valid")
    test_cases = [
        {
            'name': 'Coke Zero',
            'brand': 'Coca-Cola',
            'calories': 0,
            'protein': 0,
            'carbohydrates': 0,
            'fat': 0,
            'expected': 'has_calories should be True, quality_score > 0'
        },
        {
            'name': 'Diet Pepsi',
            'brand': 'Pepsi',
            'calories': 0,
            'expected': 'valid zero-cal drink'
        }
    ]
    
    for test in test_cases:
        cleaned = FoodDataCleaner.clean_document(test, source='openfoodfacts')
        print(f"  {test['name']}: quality_score = {cleaned['quality_score']}")
        assert cleaned['quality_score'] > 0, f"Zero-cal {test['name']} should have positive quality score"
    print("  ✅ Zero-calorie foods validated correctly")
    
    # Bug 2: Retailer matching (should not match substrings)
    print("\n🧪 BUG 2: Retailer detection should use whole-token matching")
    test_cases = [
        {
            'name': 'Aldi Style Chicken',
            'brand': 'FoodCo',
            'expected_swap': False,  # "aldi" is inside "Aldi Style", not whole token = retailer name
            'reason': 'Should NOT swap - "aldi" is part of "aldi style"'
        },
        {
            'name': 'Aldi',
            'brand': 'Chicken Breast',
            'expected_swap': True,
            'reason': 'SHOULD swap - "aldi" is exact retailer match'
        },
        {
            'name': 'Tesco Finest Chicken',
            'brand': 'Premium Foods',
            'expected_swap': False,
            'reason': 'Should NOT swap - "tesco" is product line, not swap indicator'
        }
    ]
    
    for test in test_cases:
        original_name = test['name']
        cleaned = FoodDataCleaner.clean_document(test, source='openfoodfacts')
        did_swap = cleaned['name'] != original_name
        print(f"  {test['name']}: swapped={did_swap} ({test['reason']})")
        assert did_swap == test['expected_swap'], f"Swap expectation failed for {test['name']}"
    print("  ✅ Retailer detection works correctly")
    
    # Bug 3: Short name penalty removed
    print("\n🧪 BUG 3: Short food names should not be penalized")
    test_cases = [
        {'name': 'Chicken Breast', 'calories': 120, 'protein': 26.0},
        {'name': 'Brown Rice', 'calories': 110, 'carbohydrates': 23.0},
        {'name': 'Egg', 'calories': 70, 'protein': 6.0}
    ]
    
    for test in test_cases:
        cleaned = FoodDataCleaner.clean_document(test, source='usda')
        print(f"  {test['name']}: quality_score = {cleaned['quality_score']}")
        # Should have decent score (no penalty for short names)
        assert cleaned['quality_score'] >= 20, f"{test['name']} should not be penalized for being short"
    print("  ✅ Short names not penalized")
    
    # Bug 4: Meaningful parentheticals preserved
    print("\n🧪 BUG 4: Preserve meaningful parentheticals (non-pack info)")
    test_cases = [
        {
            'name': 'Vitamin B12 (cyanocobalamin)',
            'expected_contains': 'cyanocobalamin',
            'reason': 'No digits in parentheses = preserve'
        },
        {
            'name': 'Chicken Breast (113 g)',
            'expected_not_contains': '113',
            'reason': 'Has digits + unit keyword = remove'
        },
        {
            'name': 'Omega 3 Fish Oil',
            'expected_contains': 'omega 3',
            'reason': 'Digits in name (not parentheses) = preserve'
        }
    ]
    
    for test in test_cases:
        cleaned = FoodDataCleaner.clean_document(test, source='openfoodfacts')
        name_norm = cleaned['name_norm']
        print(f"  '{test['name']}' → '{name_norm}'")
        if 'expected_contains' in test:
            assert test['expected_contains'] in name_norm, f"Should contain '{test['expected_contains']}'"
        if 'expected_not_contains' in test:
            assert test['expected_not_contains'] not in name_norm, f"Should not contain '{test['expected_not_contains']}'"
    print("  ✅ Parenthetical handling correct")
    
    # Bug 5: Brand normalization with accents
    print("\n🧪 BUG 5: Accent removal should handle all unicode")
    test_cases = [
        {'brand': 'Müller', 'expected': 'muller'},
        {'brand': 'José', 'expected': 'jose'},
        {'brand': 'Nestlé', 'expected': 'nestle'},
        {'brand': 'François', 'expected': 'francois'},
        {'brand': 'Søstrene', 'expected': 'sostrene'},
        {'brand': 'Größ', 'expected': 'gross'}
    ]
    
    for test in test_cases:
        cleaned = FoodDataCleaner.clean_document({'name': 'Test', 'brand': test['brand']}, source='openfoodfacts')
        print(f"  '{test['brand']}' → '{cleaned['brand_norm']}'")
        assert cleaned['brand_norm'] == test['expected'], f"Expected '{test['expected']}', got '{cleaned['brand_norm']}'"
    print("  ✅ Accent removal handles all unicode")
    
    # Bug 6: Country codes strictly 2 letters
    print("\n🧪 BUG 6: Country codes should be 2-letter ISO only")
    test_cases = [
        {'countries': ['en:gb'], 'expected': ['gb']},
        {'countries': ['United Kingdom', 'usa'], 'expected': ['gb', 'us']},
        {'countries': ['GBR'], 'expected': []},  # 3-letter code should be rejected
        {'countries': ['France', 'de'], 'expected': ['de', 'fr']}
    ]
    
    for test in test_cases:
        cleaned = FoodDataCleaner.clean_document({'name': 'Test', 'countries': test['countries']}, source='openfoodfacts')
        codes = sorted(cleaned['country_codes'])
        expected = sorted(test['expected'])
        print(f"  {test['countries']} → {codes}")
        assert codes == expected, f"Expected {expected}, got {codes}"
    print("  ✅ Country codes are 2-letter ISO only")
    
    # Bug 7: OFF classification strict
    print("\n🧪 BUG 7: OFF unbranded items should be 'product', not 'ingredient'")
    test_cases = [
        {
            'name': 'Chicken',
            'brand': None,
            'barcode': None,
            'source': 'openfoodfacts',
            'expected_kind': 'product',
            'expected_generic': False,
            'reason': 'OFF unbranded = product with low quality'
        },
        {
            'name': 'Chicken Breast',
            'brand': 'USDA',
            'source': 'usda',
            'expected_kind': 'ingredient',
            'expected_generic': True,
            'reason': 'USDA = ingredient'
        }
    ]
    
    for test in test_cases:
        cleaned = FoodDataCleaner.clean_document(test, source=test['source'])
        print(f"  {test['name']} ({test['source']}): kind={cleaned['food_kind']}, generic={cleaned['is_generic']}")
        assert cleaned['food_kind'] == test['expected_kind'], f"Expected {test['expected_kind']}, got {cleaned['food_kind']}"
        assert cleaned['is_generic'] == test['expected_generic'], f"Expected generic={test['expected_generic']}"
    print("  ✅ OFF classification is strict")
    
    # Bug 8: Brand prefix removal uses brand_norm
    print("\n🧪 BUG 8: Brand prefix removal should use normalized brand")
    test_cases = [
        {
            'name': 'Müller Greek Yogurt',
            'brand': 'Müller',
            'expected_norm': 'greek yogurt',
            'reason': 'Accents normalized before prefix match'
        },
        {
            'name': 'M&S Chicken',
            'brand': 'M&S',
            'expected_norm': 'chicken',
            'reason': 'Punctuation normalized before prefix match'
        }
    ]
    
    for test in test_cases:
        cleaned = FoodDataCleaner.clean_document(test, source='openfoodfacts')
        print(f"  '{test['name']}' (brand: {test['brand']}) → '{cleaned['name_norm']}'")
        assert cleaned['name_norm'] == test['expected_norm'], f"Expected '{test['expected_norm']}', got '{cleaned['name_norm']}'"
    print("  ✅ Brand prefix removal uses normalized brand")
    
    # Bug 9: Suspicious zeros penalty still works
    print("\n🧪 BUG 9: Suspicious zero-calorie penalty should still trigger")
    test_cases = [
        {
            'name': 'Suspicious Food',
            'calories': 0,
            'protein': 20.0,
            'carbohydrates': 30.0,
            'fat': 10.0,
            'expected': 'Should be heavily penalized (0 cal but high macros)'
        }
    ]
    
    for test in test_cases:
        cleaned = FoodDataCleaner.clean_document(test, source='openfoodfacts')
        print(f"  {test['name']}: quality_score = {cleaned['quality_score']} (should be low/negative)")
        # Should be penalized heavily
        assert cleaned['quality_score'] < 20, "Suspicious zero-cal with high macros should be penalized"
    print("  ✅ Suspicious zeros are still penalized")
    
    print("\n" + "=" * 80)
    print("✅ ALL 9 BUG FIXES VALIDATED SUCCESSFULLY")
    print("=" * 80)

if __name__ == '__main__':
    test_bug_fixes()
