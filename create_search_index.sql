create index if not exists foods_search_idx on foods using gin(to_tsvector('english', name || ' ' || coalesce(brand, '') || ' ' || coalesce(ingredients, '')));
