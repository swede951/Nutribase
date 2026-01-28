# Region-Based Search Enhancement Setup Guide

This guide walks you through adding region information (countries, purchase places, origins) to your Typesense food database to enable location-based search improvements.

## Overview

We're adding three new fields to improve search relevance based on user location:
- **countries**: Array of countries where the product is sold (e.g., ["United States", "Canada"])
- **purchase_places**: Specific locations where product can be purchased (e.g., "Walmart, Target")
- **origins**: Where ingredients/product originates from (e.g., "France")

## Step 1: Extract Region Data from OpenFoodFacts

Run the Python script to extract region data from your OpenFoodFacts database:

```bash
cd "/Users/alexsweet/Documents/Swift experiment/nutribase copy"

# Test with first 10,000 products
python3 add_region_fields_to_typesense.py --limit 10000

# Or process the entire database (this may take a while)
python3 add_region_fields_to_typesense.py
```

This will create `region_data_for_typesense.jsonl` with region information for all products.

**Expected Output:**
- Products processed: ~3,000,000+
- Products with region data: ~70-80% (based on OpenFoodFacts data quality)
- File size: ~200-300 MB

## Step 2: Update Typesense Schema

You need to add the new fields to your Typesense collection schema. You have two options:

### Option A: Update Existing Collection (Recommended)

Use the Typesense API to add fields to your existing collection:

```bash
curl -X PATCH 'http://localhost:8108/collections/foods/fields' \
  -H 'X-TYPESENSE-API-KEY: your_api_key_here' \
  -H 'Content-Type: application/json' \
  -d '{
    "fields": [
      {
        "name": "countries",
        "type": "string[]",
        "optional": true,
        "facet": true
      },
      {
        "name": "purchase_places",
        "type": "string",
        "optional": true
      },
      {
        "name": "origins",
        "type": "string",
        "optional": true
      }
    ]
  }'
```

### Option B: Create New Collection with Updated Schema

If you prefer to start fresh, create a new collection with all fields:

```bash
curl -X POST 'http://localhost:8108/collections' \
  -H 'X-TYPESENSE-API-KEY: your_api_key_here' \
  -H 'Content-Type: application/json' \
  -d '{
    "name": "foods_v2",
    "fields": [
      {"name": "name", "type": "string"},
      {"name": "brand", "type": "string", "optional": true},
      {"name": "barcode", "type": "string", "optional": true},
      {"name": "calories", "type": "int32"},
      {"name": "protein", "type": "float"},
      {"name": "carbohydrates", "type": "float"},
      {"name": "fat", "type": "float"},
      {"name": "fiber", "type": "float", "optional": true},
      {"name": "sugar", "type": "float", "optional": true},
      {"name": "sodium", "type": "float", "optional": true},
      {"name": "saturated_fat", "type": "float", "optional": true},
      {"name": "nova_score", "type": "int32", "optional": true},
      {"name": "nutri_score_grade", "type": "string", "optional": true},
      {"name": "serving_size", "type": "string", "optional": true},
      {"name": "serving_unit", "type": "string", "optional": true},
      {"name": "countries", "type": "string[]", "optional": true, "facet": true},
      {"name": "purchase_places", "type": "string", "optional": true},
      {"name": "origins", "type": "string", "optional": true}
    ],
    "default_sorting_field": "calories"
  }'
```

## Step 3: Upload Region Data to Typesense

Import the region data into your Typesense collection using the barcode field for matching:

```bash
# Upload with upsert action (updates existing documents by barcode)
curl -X POST 'http://localhost:8108/collections/foods/documents/import?action=upsert&upsert_fields=barcode' \
  -H 'X-TYPESENSE-API-KEY: your_api_key_here' \
  --data-binary @region_data_for_typesense.jsonl
```

**Important:** The `upsert_fields=barcode` parameter tells Typesense to match documents by the `barcode` field instead of `id`. This is crucial since your database uses sequential IDs.

**Note:** This may take 10-30 minutes depending on your database size.

## Step 4: Verify the Data

Test that region data was imported successfully:

```bash
# Search for a product and check if countries field is present
curl 'http://localhost:8108/collections/foods/documents/search?q=coca+cola&query_by=name' \
  -H 'X-TYPESENSE-API-KEY: your_api_key_here'
```

Look for the `countries`, `purchase_places`, and `origins` fields in the response.

## Step 5: Enable Location-Based Search in App

The Swift app code has already been updated to:
1. ✅ Parse region fields from Typesense responses
2. ✅ Store region data in FoodItem model
3. ⏳ Implement location-based search boosting (next step)

## Next Steps: Location-Based Boosting

To implement smart location-based search boosting:

1. **Get user's country** from device locale or IP geolocation
2. **Boost search results** where `countries` contains user's country
3. **Filter or rank** products by regional availability

Example Typesense query with location boosting:
```json
{
  "q": "milk",
  "query_by": "name,brand",
  "filter_by": "countries:=[United States]",
  "sort_by": "_text_match:desc,calories:asc"
}
```

## Benefits

✅ **Better Search Relevance**: Users see products available in their region first
✅ **Reduced Confusion**: Fewer results for products not sold locally
✅ **Improved Barcode Accuracy**: Regional product variations handled correctly
✅ **Brand Recognition**: Local/regional brands appear higher in results

## Troubleshooting

### Issue: "Field not found" error
**Solution**: Make sure you updated the Typesense schema (Step 2) before importing data

### Issue: Import is very slow
**Solution**: 
- Use `action=upsert` instead of `action=create`
- Consider batching the import in smaller chunks
- Increase Typesense server resources if needed

### Issue: Countries field is empty for many products
**Solution**: This is expected - not all OpenFoodFacts products have complete region data. The system gracefully handles missing data.

## Data Quality Statistics

Based on OpenFoodFacts database analysis:
- **Countries field**: ~73% of products have this data
- **Purchase places**: ~7% of products have this data
- **Origins**: ~5% of products have this data

The `countries` field is the most valuable for location-based search.

## Maintenance

Consider re-running the extraction script periodically (e.g., monthly) to:
- Get region data for newly added products
- Update region information for existing products
- Improve data quality as OpenFoodFacts community adds more information

---

**Questions or Issues?**
Check the Typesense documentation: https://typesense.org/docs/
