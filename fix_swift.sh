#!/bin/bash
# Fix the method declaration
sed -i '' 's/func self\.performRequestWithRetry/func performRequestWithRetry/g' "/Users/alexsweet/Documents/Swift experiment/nutribase copy/nutribase/Services/SupabaseService.swift"

# Fix the method calls in instance methods
sed -i '' 's/SupabaseService\.shared\.performRequestWithRetry/performRequestWithRetry/g' "/Users/alexsweet/Documents/Swift experiment/nutribase copy/nutribase/Services/SupabaseService.swift"

# Add [self] capture list to the closure at line 808
sed -i '' 's/DispatchQueue\.global()\.asyncAfter(deadline: \.now() + delay) {/DispatchQueue.global().asyncAfter(deadline: .now() + delay) { [self] in/g' "/Users/alexsweet/Documents/Swift experiment/nutribase copy/nutribase/Services/SupabaseService.swift"
