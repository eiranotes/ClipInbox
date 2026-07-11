# Performance Notes

- Localization is bundle-backed and requires no network access.
- Share configuration is a small App Group `UserDefaults` record read synchronously by the extension.
- Quick save queues one local payload, displays feedback for about 1.2 seconds, and completes the extension request.
- No production dependency was added.
- Existing shared-image decode caching and local-disk DerivedData workflow remain unchanged.

