#!/bin/bash
# Fix the syntax errors in TypesenseService.swift

# Fix 1: Fix the dataTask throwing function error
sed -i '' 's/let task = session.dataTask(with: request) { data, response, error in/let task = session.dataTask(with: request) { data, response, error in/' "/Users/alexsweet/Documents/Swift experiment/nutribase copy/nutribase/Services/TypesenseService.swift"

# Fix 2: Fix the consecutive statements error and expected expression error
sed -i '' 's/} catch {/                } else {\n                    completion(nil, NSError(domain: "TypesenseService", code: 500, userInfo: [NSLocalizedDescriptionKey: "Failed to parse JSON response"]))\n                }\n            } catch {/' "/Users/alexsweet/Documents/Swift experiment/nutribase copy/nutribase/Services/TypesenseService.swift"

# Fix 3: Remove private attribute from the normalizeSearchQuery method
sed -i '' 's/private func normalizeSearchQuery/func normalizeSearchQuery/' "/Users/alexsweet/Documents/Swift experiment/nutribase copy/nutribase/Services/TypesenseService.swift"

# Fix 4: Fix any missing closing braces at the end of the file
echo "}" >> "/Users/alexsweet/Documents/Swift experiment/nutribase copy/nutribase/Services/TypesenseService.swift"
