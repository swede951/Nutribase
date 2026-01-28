#!/usr/bin/env python3
"""
Data Cleaning Pipeline for Typesense Food Import
Implements Step 1 (correctness) + Step 2 (smart fields)
"""

import re
import unicodedata
from typing import Dict, List, Optional, Tuple


# ============================================================================
# STEP 1: DATA CORRECTNESS
# ============================================================================

class NameBrandSwapDetector:
    """Detects and fixes swapped name/brand fields"""
    
    # UK-focused + global retailers (normalized: lowercase, no punctuation)
    RETAILERS = {
        'aldi', 'lidl', 'tesco', 'asda', 'morrisons', 'sainsburys', 
        'sainsbury', 'waitrose', 'ms', 'marks spencer', 'marks and spencer',
        'coop', 'co op', 'spar', 'iceland', 'boots', 'superdrug',
        'poundland', 'home bargains', 'bm', 'farmfoods', 'ocado',
        'walmart', 'target', 'kroger', 'safeway', 'whole foods', 
        'trader joes', 'costco', 'carrefour', 'rewe', 'edeka',
        'auchan', 'leclerc', 'intermarche', 'super u', 'amazon'
    }
    
    # Food descriptor tokens
    FOOD_TOKENS = {
        'proteins': {'chicken', 'beef', 'pork', 'turkey', 'lamb', 'tuna', 
                    'salmon', 'cod', 'fish', 'egg', 'tofu'},
        'staples': {'rice', 'pasta', 'oats', 'bread', 'milk', 'yogurt', 
                   'cheese', 'butter', 'flour', 'sugar', 'salt'},
        'snacks': {'bar', 'shake', 'cereal', 'crisps', 'chips', 'biscuit', 
                  'cookie', 'chocolate', 'candy', 'sweets'},
        'descriptors': {'breast', 'fillet', 'mince', 'ground', 'wholemeal',
                       'skimmed', 'semi skimmed', 'low fat', 'high protein',
                       'slice', 'portion', 'raw', 'cooked', 'fresh', 'frozen'}
    }
    
    @classmethod
    def normalize_text(cls, text: str) -> str:
        """Normalize text for comparison (lowercase, no punctuation)"""
        if not text:
            return ''
        # Remove punctuation, lowercase
        text = re.sub(r'[^\w\s]', ' ', text.lower())
        # Collapse multiple spaces
        text = re.sub(r'\s+', ' ', text).strip()
        return text
    
    @classmethod
    def is_retailer(cls, text: str) -> bool:
        """Check if text matches retailer pattern (whole token matching)"""
        normalized = cls.normalize_text(text)
        tokens = normalized.split()
        
        # Exact match - strong signal
        if normalized in cls.RETAILERS:
            return True
        
        # Token-based matching - check if retailer is a whole word
        for retailer in cls.RETAILERS:
            retailer_tokens = retailer.split()
            # Single-token retailers must match exactly as a token
            if len(retailer_tokens) == 1 and retailer in tokens:
                return True
            # Multi-token retailers: check if all tokens appear consecutively
            elif len(retailer_tokens) > 1:
                retailer_str = ' '.join(retailer_tokens)
                if retailer_str in normalized:
                    return True
        
        # Short strings (1-2 tokens) are more likely to be retailers
        if len(tokens) <= 2:
            for token in tokens:
                if token in cls.RETAILERS:
                    return True
        
        return False
    
    @classmethod
    def calculate_food_score(cls, text: str) -> int:
        """Calculate how 'food-like' a text is (higher = more food-like)"""
        if not text:
            return 0
        
        normalized = cls.normalize_text(text)
        tokens = normalized.split()
        score = 0
        
        # Count food tokens
        for category, words in cls.FOOD_TOKENS.items():
            for word in words:
                if word in normalized:
                    score += 2 if category == 'proteins' else 1
        
        # Boost for measurement patterns (100g, 500ml, etc.)
        if re.search(r'\d+\s*(g|ml|kg|l|oz|lb)', normalized):
            score += 1
        
        # Boost for percentage (5%, 2%, etc.)
        if re.search(r'\d+%', normalized):
            score += 1
        
        # No penalty for short names - "chicken breast" is 2 tokens and perfectly valid
        
        return max(0, score)
    
    @classmethod
    def should_swap(cls, name: str, brand: str) -> bool:
        """Determine if name and brand should be swapped"""
        if not name or not brand:
            return False
        
        # Check all conditions
        name_is_retailer = cls.is_retailer(name)
        brand_is_retailer = cls.is_retailer(brand)
        
        # Don't swap if both or neither are retailers
        if name_is_retailer == brand_is_retailer:
            return False
        
        # Swap if name is retailer and brand is not
        if name_is_retailer and not brand_is_retailer:
            brand_food_score = cls.calculate_food_score(brand)
            # Only swap if brand has food characteristics
            if brand_food_score >= 2:
                return True
        
        return False


class CountryCodeNormalizer:
    """Normalizes country strings to ISO codes"""
    
    # Country name to ISO code mapping
    COUNTRY_MAP = {
        'united kingdom': 'gb',
        'uk': 'gb',
        'great britain': 'gb',
        'united states': 'us',
        'usa': 'us',
        'ireland': 'ie',
        'france': 'fr',
        'germany': 'de',
        'spain': 'es',
        'italy': 'it',
        'netherlands': 'nl',
        'belgium': 'be',
        'sweden': 'se',
        'norway': 'no',
        'denmark': 'dk',
        'poland': 'pl',
        'portugal': 'pt',
        'switzerland': 'ch',
        'austria': 'at',
        'australia': 'au',
        'canada': 'ca',
        'new zealand': 'nz',
        'all regions': 'all'
    }
    
    @classmethod
    def normalize_country(cls, country_str: str) -> Optional[str]:
        """Convert a country string to ISO 2-letter code"""
        if not country_str:
            return None
        
        # Handle OFF tag format: "en:gb" → "gb"
        if ':' in country_str:
            parts = country_str.split(':')
            country_str = parts[-1]  # Take part after last colon
        
        # Normalize and lookup
        normalized = country_str.lower().strip()
        
        # Check if it's already a 2-letter ISO code (strict: only 2 letters)
        if len(normalized) == 2 and normalized.isalpha():
            return normalized
        
        # Look up in mapping
        return cls.COUNTRY_MAP.get(normalized)
    
    @classmethod
    def normalize_countries(cls, countries: List[str]) -> List[str]:
        """Normalize a list of country strings to ISO codes"""
        if not countries:
            return []
        
        codes = set()
        for country in countries:
            code = cls.normalize_country(country)
            if code:
                codes.add(code)
        
        return sorted(list(codes))


class NumericCoercer:
    """Coerces nutrition fields to proper numeric types"""
    
    @staticmethod
    def safe_int(value, default=None) -> Optional[int]:
        """Convert to int or return None"""
        if value is None or value == '':
            return default
        try:
            return int(float(value))
        except (ValueError, TypeError):
            return default
    
    @staticmethod
    def safe_float(value, default=None) -> Optional[float]:
        """Convert to float or return None"""
        if value is None or value == '':
            return default
        try:
            return float(value)
        except (ValueError, TypeError):
            return default


# ============================================================================
# STEP 2: SMART FIELDS
# ============================================================================

class NameNormalizer:
    """Normalizes food names for better search"""
    
    # Pack/unit keywords that signal removable parenthetical info
    PACK_UNIT_KEYWORDS = [
        'pack', 'count', 'ct', 'serving', 'portion', 'slice', 'bar', 'piece',
        'g', 'kg', 'oz', 'lb', 'ml', 'l', 'fl oz'
    ]
    
    # Unit patterns to remove (non-parenthetical)
    UNIT_PATTERNS = [
        # Weight units
        r'\d+\s*g\b',  # 500g, 500 g
        r'\d+\s*kg\b',  # 0.5kg, 2 kg
        r'\d+\s*oz\b',  # 12 oz
        r'\d+\s*lb\b',  # 1 lb
        
        # Volume units
        r'\d+\s*ml\b',  # 200ml, 200 ml
        r'\d+\s*l\b',  # 1 l
        r'\d+\s*fl\s*oz\b',  # 12 fl oz
        
        # Count/pack patterns
        r'\d+\s*x\s*\d*',  # 2x, 6x100g
        r'x\s*\d+',  # x2, x6
        r'\d+\s*pack',  # 6 pack, 6-pack
        r'pack\s+of\s+\d+',  # pack of 6
        r'\d+\s*count',  # 10 count
        r'\d+\s*ct\b',  # 10ct
        
        # Serving/count words with numbers
        r'\d+\s*portion',  # 1 portion
        r'\d+\s*slice',  # 2 slices
        r'\d+\s*bar',  # 6 bars
        r'\d+\s*piece',  # 12 pieces
    ]
    
    @classmethod
    def should_remove_parenthetical(cls, text: str) -> bool:
        """Check if parenthetical content should be removed (contains units/pack info)"""
        text_lower = text.lower()
        # Has digits AND contains pack/unit keywords
        has_digits = bool(re.search(r'\d', text))
        has_pack_keyword = any(keyword in text_lower for keyword in cls.PACK_UNIT_KEYWORDS)
        return has_digits and has_pack_keyword
    
    @classmethod
    def normalize_name(cls, name: str, brand: Optional[str] = None) -> str:
        """
        Normalize food name:
        - Lowercase
        - Remove punctuation
        - Remove unit/pack patterns
        - Remove brand prefix (if safe)
        """
        if not name:
            return ''
        
        normalized = name.lower()
        
        # Remove accents from name (so "Müller" matches "muller" brand prefix)
        normalized = unicodedata.normalize('NFD', normalized)
        normalized = ''.join(char for char in normalized if unicodedata.category(char) != 'Mn')
        
        # Remove parenthetical content only if it contains pack/unit info
        # This preserves meaningful parentheticals like "Vitamin B12 (cyanocobalamin)"
        def replace_parenthetical(match):
            content = match.group(1)
            if cls.should_remove_parenthetical(content):
                return ' '
            return match.group(0)  # Keep it
        
        normalized = re.sub(r'\(([^)]+)\)', replace_parenthetical, normalized)
        normalized = re.sub(r'\[([^\]]+)\]', replace_parenthetical, normalized)
        
        # Remove unit/pack patterns
        for pattern in cls.UNIT_PATTERNS:
            normalized = re.sub(pattern, ' ', normalized, flags=re.IGNORECASE)
        
        # Remove punctuation except % (BEFORE brand prefix check)
        normalized = re.sub(r'[^\w\s%]', ' ', normalized)
        normalized = re.sub(r'\s+', ' ', normalized).strip()  # Collapse spaces
        
        # Remove brand prefix using normalized brand (not raw brand)
        if brand:
            brand_norm = BrandNormalizer.normalize_brand(brand)
            if brand_norm and normalized.startswith(brand_norm):
                # Remove brand prefix
                normalized = normalized[len(brand_norm):].strip()
        
        # Collapse multiple spaces
        normalized = re.sub(r'\s+', ' ', normalized).strip()
        
        return normalized


class BrandNormalizer:
    """Normalizes brand names"""
    
    @staticmethod
    def normalize_brand(brand: str) -> str:
        """
        Normalize brand name:
        - Lowercase
        - Remove accents/special chars using unicodedata
        - Deduplicate (Aldi, Aldi → aldi)
        """
        if not brand:
            return ''
        
        # Split by comma and take first non-empty part
        parts = brand.split(',')
        brand = parts[0].strip() if parts else brand
        
        # Lowercase
        normalized = brand.lower()
        
        # Manual replacements for special letters that don't decompose with NFD
        special_chars = {
            'ø': 'o', 'æ': 'ae', 'œ': 'oe', 'ß': 'ss',
            'ð': 'd', 'þ': 'th', 'đ': 'd', 'ł': 'l'
        }
        for special, replacement in special_chars.items():
            normalized = normalized.replace(special, replacement)
        
        # Remove accents using unicode normalization (handles most accented chars)
        # NFD = decompose accented chars into base + accent, then filter out accents
        normalized = unicodedata.normalize('NFD', normalized)
        normalized = ''.join(char for char in normalized if unicodedata.category(char) != 'Mn')
        
        # Remove punctuation (replace with space for consistency with name normalization)
        normalized = re.sub(r'[^\w\s]', ' ', normalized)
        
        # Collapse spaces
        normalized = re.sub(r'\s+', ' ', normalized).strip()
        
        return normalized


class FoodKindClassifier:
    """Classifies food into ingredient/product/restaurant"""
    
    RESTAURANT_BRANDS = {
        'mcdonalds', 'mcdonald', 'kfc', 'subway', 'burger king',
        'wendys', 'wendy', 'starbucks', 'dominos', 'domino',
        'pizza hut', 'taco bell', 'greggs', 'pret', 'pret a manger',
        'five guys', 'nandos', 'nando', 'tim hortons', 'chipotle',
        'panera', 'chick fil a', 'popeyes', 'arbys', 'sonic'
    }
    
    @classmethod
    def classify(cls, name: str, brand: Optional[str], barcode: Optional[str], 
                 source: str = 'openfoodfacts') -> str:
        """
        Classify food kind:
        - 'ingredient': USDA only (strict)
        - 'restaurant': Restaurant chain foods
        - 'product': Branded products (default, includes OFF unbranded)
        """
        # Check for restaurant
        brand_norm = BrandNormalizer.normalize_brand(brand or '')
        name_lower = name.lower()
        
        if any(restaurant in brand_norm for restaurant in cls.RESTAURANT_BRANDS):
            return 'restaurant'
        
        if any(name_lower.startswith(restaurant) for restaurant in cls.RESTAURANT_BRANDS):
            return 'restaurant'
        
        # Only USDA is classified as ingredient (strict)
        # OFF unbranded items should be 'product' with low quality_score
        if source.lower() == 'usda':
            return 'ingredient'
        
        # Default: product (even if no brand/barcode - let quality_score rank it low)
        return 'product'


class GenericDetector:
    """Determines if a food is generic/canonical"""
    
    @staticmethod
    def is_generic(food_kind: str, brand: Optional[str], barcode: Optional[str],
                   name: str) -> bool:
        """
        Determine if food is generic (strict):
        - True: ingredient (USDA) or explicitly generic brand
        - False: everything else (branded, restaurant, OFF unbranded)
        """
        # Ingredients are always generic (USDA only)
        if food_kind == 'ingredient':
            return True
        
        # Restaurants are never generic
        if food_kind == 'restaurant':
            return False
        
        # Only USDA/Generic brand is generic
        if brand and brand.lower() in ['usda', 'generic']:
            return True
        
        # Everything else is NOT generic (including OFF unbranded)
        # Let quality_score differentiate instead
        return False


class QualityScorer:
    """Calculates quality score (0-100) based on completeness + trust"""
    
    @staticmethod
    def calculate(doc: Dict) -> int:
        """
        Calculate quality score:
        A) Nutrition completeness (max 50)
        B) Serving data (max 15)
        C) Identity/traceability (max 20)
        D) Extra metadata (max 10)
        E) Penalties (up to -40)
        F) Source trust multiplier (optional)
        """
        score = 0
        
        # A) Nutrition completeness (max 50)
        cal = doc.get('calories')
        has_calories = cal is not None  # 0 calories is valid (e.g., Coke Zero)
        has_protein = doc.get('protein') is not None
        has_carbs = doc.get('carbohydrates') is not None
        has_fat = doc.get('fat') is not None
        
        if has_calories:
            score += 10
        if has_protein:
            score += 10
        if has_carbs:
            score += 10
        if has_fat:
            score += 10
        
        # Bonus for all 4
        if has_calories and has_protein and has_carbs and has_fat:
            score += 10
        
        # B) Serving data (max 15)
        if doc.get('serving_size'):
            score += 10
        if doc.get('serving_unit'):
            score += 5
        
        # C) Identity/traceability (max 20)
        if doc.get('barcode'):
            score += 15
        if doc.get('brand'):
            score += 5
        
        # D) Extra metadata (max 10)
        if doc.get('nova_score') and doc.get('nova_score') > 0:
            score += 5
        if doc.get('nutriscore_grade'):
            score += 5
        
        # E) Penalties
        # Suspicious zeros: calories == 0 but macros have values
        calories = doc.get('calories', 0)
        protein = doc.get('protein', 0) or 0
        carbs = doc.get('carbohydrates', 0) or 0
        fat = doc.get('fat', 0) or 0
        
        if calories == 0 and (protein > 5 or carbs > 5 or fat > 5):
            score -= 30
        
        # Junk name patterns
        name = (doc.get('name') or '').lower()
        if any(junk in name for junk in ['test', 'asdf', 'unknown', 'xxx']):
            score -= 50
        
        # F) Source trust multiplier
        source = doc.get('source', 'openfoodfacts').lower()
        if source == 'usda':
            score = int(score * 1.1)
        elif source == 'openfoodfacts' and not doc.get('barcode'):
            score = int(score * 0.9)
        
        # Cap at 0-100
        return max(0, min(100, score))


# ============================================================================
# MAIN CLEANING PIPELINE
# ============================================================================

class FoodDataCleaner:
    """Main pipeline for cleaning food data"""
    
    @staticmethod
    def clean_document(doc: Dict, source: str = 'openfoodfacts') -> Dict:
        """
        Apply full cleaning pipeline to a food document.
        
        Args:
            doc: Raw food document
            source: 'usda' or 'openfoodfacts'
        
        Returns:
            Cleaned document with all Step 1 + Step 2 fields
        """
        cleaned = doc.copy()
        
        # STEP 1: Fix swapped name/brand
        name = doc.get('name', '')
        brand = doc.get('brand', '')
        
        if NameBrandSwapDetector.should_swap(name, brand):
            cleaned['name'] = brand
            cleaned['brand'] = name
            print(f"  🔄 Swapped name/brand: '{name}' ↔ '{brand}'")
        
        # Clean brand (remove duplicates)
        if cleaned.get('brand'):
            parts = cleaned['brand'].split(',')
            cleaned['brand'] = parts[0].strip()
        
        # STEP 1: Normalize countries to ISO codes
        countries = doc.get('countries', [])
        if countries:
            cleaned['country_codes'] = CountryCodeNormalizer.normalize_countries(countries)
        else:
            cleaned['country_codes'] = []
        
        # STEP 1: Coerce numeric fields to proper types (null for missing)
        cleaned['calories'] = NumericCoercer.safe_int(doc.get('calories'))
        cleaned['protein'] = NumericCoercer.safe_float(doc.get('protein'))
        cleaned['carbohydrates'] = NumericCoercer.safe_float(doc.get('carbohydrates'))
        cleaned['fat'] = NumericCoercer.safe_float(doc.get('fat'))
        cleaned['fiber'] = NumericCoercer.safe_float(doc.get('fiber'))
        cleaned['sugar'] = NumericCoercer.safe_float(doc.get('sugar'))
        cleaned['sodium'] = NumericCoercer.safe_float(doc.get('sodium'))
        cleaned['saturated_fat'] = NumericCoercer.safe_float(doc.get('saturated_fat'))
        
        # STEP 2: Add name_norm
        cleaned['name_norm'] = NameNormalizer.normalize_name(
            cleaned.get('name', ''),
            cleaned.get('brand')
        )
        
        # STEP 2: Add brand_norm
        cleaned['brand_norm'] = BrandNormalizer.normalize_brand(
            cleaned.get('brand', '')
        )
        
        # STEP 2: Add food_kind
        cleaned['food_kind'] = FoodKindClassifier.classify(
            cleaned.get('name', ''),
            cleaned.get('brand'),
            cleaned.get('barcode'),
            source
        )
        
        # STEP 2: Add is_generic
        cleaned['is_generic'] = GenericDetector.is_generic(
            cleaned['food_kind'],
            cleaned.get('brand'),
            cleaned.get('barcode'),
            cleaned.get('name', '')
        )
        
        # STEP 2: Add quality_score
        cleaned['source'] = source
        cleaned['quality_score'] = QualityScorer.calculate(cleaned)
        
        # STEP 2: Add popularity (starts at 0)
        cleaned['popularity'] = 0
        
        # STEP 2.5: Derive serving_unit from serving_size if not present
        if not cleaned.get('serving_unit') and cleaned.get('serving_size'):
            serving_size = str(cleaned['serving_size']).lower()
            if 'ml' in serving_size:
                cleaned['serving_unit'] = 'ml'
            elif 'g' in serving_size:
                cleaned['serving_unit'] = 'g'
            elif 'oz' in serving_size:
                cleaned['serving_unit'] = 'oz'
        
        # STEP 2.5: Create ingredients_text string for NOVA estimation
        # (schema stores ingredients as string[], but estimator needs text for pattern matching)
        raw_ing = cleaned.get('ingredients') or []
        if isinstance(raw_ing, list):
            cleaned['ingredients_text'] = ', '.join(str(i) for i in raw_ing if i)
        elif isinstance(raw_ing, str):
            cleaned['ingredients_text'] = raw_ing
        else:
            cleaned['ingredients_text'] = ''
        
        # STEP 2.5: Estimate NOVA if missing or validate existing
        nova_estimated, nova_source, nova_confidence = NovaEstimator.estimate_nova(cleaned)
        
        # If we have real NOVA from source, keep it but add metadata
        if nova_source == 'off':
            cleaned['nova_estimated'] = None
            cleaned['nova_source'] = 'off'
            cleaned['nova_confidence'] = 1.0
        # If we estimated it
        elif nova_source == 'estimated':
            cleaned['nova_estimated'] = nova_estimated
            cleaned['nova_source'] = 'estimated'
            cleaned['nova_confidence'] = nova_confidence
        # If unknown
        else:
            cleaned['nova_estimated'] = None
            cleaned['nova_source'] = 'unknown'
            cleaned['nova_confidence'] = 0.0
        
        # STEP 2.5: Add nova_final for easy filtering (nova_score if present, else nova_estimated)
        cleaned['nova_final'] = cleaned.get('nova_score') or cleaned.get('nova_estimated')
        
        return cleaned


# ============================================================================
# NOVA ESTIMATION (STEP 2.5) - Production Version
# ============================================================================

class NovaEstimator:
    """
    Estimates NOVA score using deterministic decision tree.
    
    Works with schema where:
    - ingredients: string[] (array of ingredient strings)
    - categories: string[] (array of category strings)
    
    Key improvements:
    1. Proper handling of string[] fields from Typesense schema
    2. Better ingredient parsing (semicolons, parentheticals)
    3. Category-based UPF detection requires additional signals
    4. Branded whole foods allowed with lower confidence
    5. Expanded additive/industrial keyword lists
    """
    
    # NOVA 2 culinary ingredient keywords
    CULINARY_INGREDIENTS = {
        'oil', 'olive oil', 'vegetable oil', 'sunflower oil', 'coconut oil', 'rapeseed oil',
        'butter', 'ghee', 'lard',
        'sugar', 'caster sugar', 'brown sugar', 'icing sugar', 'demerara sugar',
        'salt', 'sea salt', 'table salt', 'rock salt',
        'flour', 'wheat flour', 'plain flour', 'self-raising flour', 'bread flour',
        'honey', 'maple syrup', 'golden syrup',
        'vinegar', 'balsamic vinegar', 'wine vinegar', 'cider vinegar'
    }
    
    # Additive keywords (strong NOVA 4 signals) - EXPANDED
    ADDITIVE_KEYWORDS = {
        # Emulsifiers/stabilizers
        'emulsifier', 'emulsifiers', 'stabiliser', 'stabilizer', 'stabilisers', 'stabilizers',
        'thickener', 'thickeners', 'gelling agent', 'gelling agents',
        # Gums
        'gum', 'xanthan', 'xanthan gum', 'guar', 'guar gum', 'locust bean gum', 'cellulose gum',
        'lecithin', 'soy lecithin', 'sunflower lecithin',
        # Flavourings
        'flavouring', 'flavourings', 'flavoring', 'flavorings', 
        'natural flavouring', 'natural flavourings', 'natural flavoring', 'natural flavorings',
        'artificial flavour', 'artificial flavor',
        # Colours
        'colour', 'color', 'colours', 'colors', 'colouring', 'coloring', 'colourant',
        # Sweeteners
        'sweetener', 'sweeteners',
        # Preservatives
        'preservative', 'preservatives',
        # Other common additives (excluding 'raising agents' - common in NOVA 2 flour)
        'acidity regulator', 'acidity regulators',
        'antioxidant', 'antioxidants',
        'humectant', 'humectants',
        'anti-caking agent', 'anticaking agent',
        'mono- and diglycerides', 'mono and diglycerides', 'diglycerides'
    }
    
    # Industrial ingredients (strong NOVA 4 signals) - EXPANDED
    INDUSTRIAL_INGREDIENTS = {
        'maltodextrin',
        'modified starch', 'modified corn starch', 'modified maize starch', 'modified tapioca starch',
        'glucose syrup', 'fructose syrup', 'glucose-fructose syrup', 'high fructose corn syrup',
        'invert sugar', 'invert syrup',
        'dextrose', 'dextrin',
        'protein isolate', 'soy protein isolate', 'whey protein isolate', 'milk protein isolate',
        'protein concentrate', 'whey protein concentrate', 'milk protein concentrate',
        'hydrolysed protein', 'hydrolyzed protein', 'hydrolysed vegetable protein',
        'hydrogenated oil', 'partially hydrogenated oil', 'hydrogenated fat', 'hydrogenated vegetable oil',
        'flavour enhancer', 'flavor enhancer', 'monosodium glutamate', 'msg',
        'carrageenan', 'pectin',
        'polydextrose',
        'maltitol', 'sorbitol', 'xylitol', 'erythritol', 'mannitol',
        'aspartame', 'sucralose', 'acesulfame k', 'acesulfame potassium', 'saccharin', 'stevia extract',
        'mechanically separated', 'mechanically recovered',
        'interesterified fat', 'fractionated oil',
        # Fortification additives
        'calcium carbonate', 'calcium phosphate', 'calcium phosphates',
        'vitamin d', 'vitamin b12', 'added vitamins'
    }
    
    # Ultra-processed category indicators - MORE SPECIFIC
    # These are strong UPF signals that alone suggest NOVA 4
    UPF_CATEGORIES_STRONG = {
        'energy drink', 'energy drinks',
        'instant noodles', 'instant soup',
        'breakfast cereal', 'breakfast cereals',
        'ice cream', 'frozen dessert',
        'confectionery', 'candy', 'sweets',
        'chocolate bar', 'chocolate bars',
        'ready meal', 'ready meals', 'frozen meal', 'microwave meal',
        'nuggets', 'fish fingers', 'chicken nuggets',
        'soft drink', 'soft drinks', 'soda', 'fizzy drink',
        'biscuits', 'cookies', 'biscuit', 'cookie'  # Industrial baked goods
    }
    
    # Weaker UPF category signals - need additional evidence
    UPF_CATEGORIES_WEAK = {
        'snacks', 'crisps', 'chips', 
        'cereal bar', 'protein bar',
        'sauce', 'sauces'
    }
    
    # Mixed product indicators (disqualify from NOVA 2)
    MIXED_PRODUCT_WORDS = {'with', 'and', 'flav', 'season', 'mix', 'sauce', 'spread', 'dressing'}
    
    @classmethod
    def _normalize_ingredients(cls, doc: Dict) -> Tuple[str, List[str], int]:
        """
        Normalize ingredients from string[] or string format.
        
        Returns:
            Tuple of (normalized_text, ingredient_list, ingredient_count)
        """
        raw_ingredients = doc.get('ingredients') or doc.get('ingredients_text') or []
        
        # Handle string[] (from Typesense schema)
        if isinstance(raw_ingredients, list):
            # Filter empty strings and normalize
            ingredient_list = [str(i).strip().lower() for i in raw_ingredients if i and str(i).strip()]
            ingredients_text = ' '.join(ingredient_list)
        else:
            # Handle string format
            ingredients_text = str(raw_ingredients).lower()
            # Better splitting: remove parentheticals first, then split on comma/semicolon
            cleaned_text = re.sub(r'\([^)]*\)', '', ingredients_text)
            ingredient_list = [i.strip() for i in re.split(r'[;,]', cleaned_text) if i.strip()]
        
        ingredient_count = len(ingredient_list)
        return (ingredients_text, ingredient_list, ingredient_count)
    
    @classmethod
    def _normalize_categories(cls, doc: Dict) -> Tuple[str, List[str]]:
        """
        Normalize categories from string[] or string format.
        
        Returns:
            Tuple of (normalized_text, category_list)
        """
        raw_categories = doc.get('categories') or []
        
        # Handle string[] (from Typesense schema)
        if isinstance(raw_categories, list):
            category_list = [str(c).strip().lower() for c in raw_categories if c and str(c).strip()]
            categories_text = ' '.join(category_list)
        else:
            # Handle string format
            categories_text = str(raw_categories).lower()
            category_list = [c.strip() for c in categories_text.split(',') if c.strip()]
        
        return (categories_text, category_list)
    
    @classmethod
    def _count_upf_signals(cls, ingredients_text: str, categories_text: str, name: str) -> Dict[str, int]:
        """Count all UPF signals in the document."""
        # E-number detection
        e_number_hits = len(re.findall(r'\be\s?\d{3,4}[a-z]?\b', ingredients_text, re.IGNORECASE))
        
        # Additive keyword detection
        additive_hits = sum(1 for keyword in cls.ADDITIVE_KEYWORDS if keyword in ingredients_text)
        
        # Industrial ingredient detection
        industrial_hits = sum(1 for keyword in cls.INDUSTRIAL_INGREDIENTS if keyword in ingredients_text)
        
        # Strong UPF category detection (in categories OR name)
        strong_category_hits = sum(1 for keyword in cls.UPF_CATEGORIES_STRONG 
                                   if keyword in categories_text or keyword in name)
        
        # Weak UPF category detection
        weak_category_hits = sum(1 for keyword in cls.UPF_CATEGORIES_WEAK 
                                 if keyword in categories_text or keyword in name)
        
        return {
            'e_numbers': e_number_hits,
            'additives': additive_hits,
            'industrial': industrial_hits,
            'strong_categories': strong_category_hits,
            'weak_categories': weak_category_hits,
            'total_hard': e_number_hits + additive_hits + industrial_hits
        }
    
    @classmethod
    def estimate_nova(cls, doc: Dict) -> Tuple[Optional[int], str, float]:
        """
        Estimate NOVA score using two-stage decision tree.
        
        Stage A: Hard rules (E-numbers, industrial ingredients)
        Stage B: Soft signals (categories, ingredient count, additives)
        
        Args:
            doc: Food document with ingredients/categories (as string[])
            
        Returns:
            Tuple of (nova_estimated, nova_source, nova_confidence)
        """
        # Check if we already have a real NOVA score from OFF
        existing_nova = doc.get('nova_score')
        if existing_nova and isinstance(existing_nova, (int, float)) and existing_nova > 0:
            return (int(existing_nova), 'off', 1.0)
        
        # Normalize inputs
        ingredients_text, ingredient_list, ingredient_count = cls._normalize_ingredients(doc)
        categories_text, category_list = cls._normalize_categories(doc)
        name = (doc.get('name') or '').lower()
        has_brand = bool(doc.get('brand'))
        
        # Count UPF signals
        signals = cls._count_upf_signals(ingredients_text, categories_text, name)
        
        # ========================================
        # NO INGREDIENTS PATH
        # ========================================
        if not ingredients_text or len(ingredients_text) < 3:
            # Check if name suggests whole food
            whole_food_keywords = {
                'chicken breast', 'chicken thigh', 'beef', 'pork', 'turkey', 'lamb', 'steak',
                'salmon', 'tuna', 'cod', 'fish fillet', 'prawns', 'shrimp',
                'egg', 'eggs',
                'milk', 'whole milk', 'semi-skimmed milk', 'skimmed milk',
                'oats', 'rice', 'quinoa', 'pasta', 'couscous',
                'apple', 'banana', 'orange', 'tomato', 'potato', 'carrot', 'broccoli', 'spinach'
            }
            
            for keyword in whole_food_keywords:
                if keyword in name:
                    # FIX #2: Allow branded whole foods with lower confidence
                    conf = 0.7 if not has_brand else 0.55
                    return (1, 'estimated', conf)
            
            # Check if it's a culinary ingredient
            for culinary in cls.CULINARY_INGREDIENTS:
                if culinary in name:
                    # FIX #3: Guard against mixed products
                    if not any(x in name for x in cls.MIXED_PRODUCT_WORDS):
                        return (2, 'estimated', 0.75)
            
            # No data to estimate
            return (None, 'unknown', 0.0)
        
        # ========================================
        # STAGE A: HARD RULES (HIGH CONFIDENCE)
        # ========================================
        
        # A1: E-numbers OR industrial ingredients → NOVA 4
        if signals['e_numbers'] > 0 or signals['industrial'] > 0:
            confidence = 0.85
            if signals['e_numbers'] >= 2 or signals['industrial'] >= 2:
                confidence = 0.95
            elif signals['total_hard'] >= 3:
                confidence = 0.9
            return (4, 'estimated', confidence)
        
        # A2: NOVA 2 - Culinary ingredients (strict check)
        is_culinary = any(culinary in name for culinary in cls.CULINARY_INGREDIENTS)
        # FIX #3: Only NOVA 2 if it's basically just the culinary ingredient
        is_simple_product = (
            ingredient_count <= 3 and 
            not any(x in name for x in cls.MIXED_PRODUCT_WORDS) and
            len(name.split()) <= 4  # Short name
        )
        
        if is_culinary and is_simple_product and signals['additives'] == 0:
            return (2, 'estimated', 0.8)
        
        # A3: NOVA 1 - Minimally processed (strict check)
        # Exclude processed product types: cakes, bars, chips, pasta, cured meats, etc.
        processed_product_words = {'cake', 'cakes', 'bar', 'bars', 'chip', 'chips', 'crisp', 'crisps', 
                                   'puff', 'puffed', 'flakes', 'nugget', 'nuggets', 'stick', 'sticks',
                                   'pasta', 'spaghetti', 'tagliatelle', 'penne', 'fusilli', 'noodles',
                                   'prosciutto', 'salami', 'ham', 'bacon', 'chorizo', 'pepperoni'}
        is_processed_type = any(word in name for word in processed_product_words)
        
        if ingredient_count <= 2 and signals['total_hard'] == 0 and signals['additives'] == 0:
            if not any(word in name for word in ['sauce', 'flavoured', 'seasoned', 'prepared', 'coated']):
                if not is_culinary and not is_processed_type:
                    # FIX #2: Allow branded with lower confidence
                    conf = 0.85 if not has_brand else 0.7
                    return (1, 'estimated', conf)
        
        # ========================================
        # STAGE B: SOFT SIGNALS
        # ========================================
        
        # B1: Multiple additive hits → NOVA 4
        if signals['additives'] >= 2:
            confidence = 0.8
            if signals['additives'] >= 3:
                confidence = 0.85
            return (4, 'estimated', confidence)
        
        # B1.5: Single additive with many ingredients (6+) suggests industrial formulation → NOVA 4
        if signals['additives'] >= 1 and ingredient_count >= 6:
            return (4, 'estimated', 0.75)
        
        # B2: Strong UPF category → NOVA 4
        if signals['strong_categories'] >= 1:
            return (4, 'estimated', 0.85)
        
        # B3: Weak UPF category + at least one additive signal → NOVA 4
        # FIX #4: Category alone doesn't force NOVA 4
        if signals['weak_categories'] >= 1 and signals['additives'] >= 1:
            return (4, 'estimated', 0.75)
        
        # ========================================
        # NOVA 3: PROCESSED FOODS (FALLBACK)
        # ========================================
        if ingredient_count >= 2:
            confidence = 0.65
            
            # Higher confidence with good ingredient data
            if 3 <= ingredient_count <= 8:
                confidence = 0.75
            
            # Traditional processing indicators boost confidence
            traditional_keywords = {'salt', 'sugar', 'water', 'yeast', 'vinegar', 'fermented', 'cultured', 'smoked', 'cured'}
            traditional_hits = sum(1 for kw in traditional_keywords if kw in ingredients_text)
            if traditional_hits >= 1:
                confidence += 0.05
            
            # Yogurt/cheese with sugar/salt = NOVA 3
            has_fermentation = any(w in ingredients_text for w in ['culture', 'cultures', 'yogurt', 'yoghurt'])
            has_simple_additions = any(w in ingredients_text for w in ['sugar', 'salt'])
            if has_fermentation and has_simple_additions and ingredient_count <= 4:
                confidence = 0.75
            
            return (3, 'estimated', min(0.8, confidence))
        
        # Default: unknown
        return (None, 'unknown', 0.0)


# ============================================================================
# UTILITY FUNCTIONS
# ============================================================================

def test_cleaning():
    """Test the cleaning pipeline with sample data"""
    
    test_cases = [
        {
            'name': 'Aldi',
            'brand': 'Chicken Breast',
            'countries': ['en:gb', 'United Kingdom'],
            'calories': '165',
            'protein': '31.0',
            'barcode': '1234567890'
        },
        {
            'name': 'Chicken Breast (113 g)',
            'brand': 'Tesco',
            'countries': ['United States', 'uk'],
            'calories': 120,
            'protein': 26.0
        },
        {
            'name': 'Müller Yogurt',
            'brand': 'Müller, Müller',
            'countries': ['en:de', 'en:gb'],
            'calories': 90
        }
    ]
    
    print("Testing data cleaning pipeline...\n")
    
    for i, test_doc in enumerate(test_cases, 1):
        print(f"Test Case {i}:")
        print(f"  Input: {test_doc}")
        cleaned = FoodDataCleaner.clean_document(test_doc, source='openfoodfacts')
        print(f"  Output:")
        print(f"    name: {cleaned.get('name')}")
        print(f"    brand: {cleaned.get('brand')}")
        print(f"    name_norm: {cleaned.get('name_norm')}")
        print(f"    brand_norm: {cleaned.get('brand_norm')}")
        print(f"    country_codes: {cleaned.get('country_codes')}")
        print(f"    food_kind: {cleaned.get('food_kind')}")
        print(f"    is_generic: {cleaned.get('is_generic')}")
        print(f"    quality_score: {cleaned.get('quality_score')}")
        print()


if __name__ == '__main__':
    test_cleaning()
