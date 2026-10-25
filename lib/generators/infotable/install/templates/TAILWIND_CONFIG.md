# Tailwind Configuration for InfoTable

InfoTable supports both Tailwind CSS v4 (recommended) and v3.

## Tailwind v4 (CSS-based Config) - RECOMMENDED

Tailwind v4 uses CSS-based configuration with `@source` directives. The installer creates a separate CSS file for InfoTable.

### What the Installer Does

When you run `rails generate infotable:install`, it:

1. **Creates `app/assets/stylesheets/infotable.css`** with ENV variable references:
```css
/* InfoTable Tailwind Sources */

/* Local table definitions in your Rails app */
@source "../../app/infotable";

/* InfoTable gem paths (resolved dynamically via ENV variables) */
@source "$INFOTABLE_VIEWS_PATH";
@source "$INFOTABLE_FORMATTERS_PATH";
```

2. **Adds import to `application.tailwind.css`**:
```css
@import "tailwindcss";

/* InfoTable gem styles */
@import './infotable';
```

### Why This Approach?

- **Always correct**: Rails engine knows the exact gem location
- **Environment-agnostic**: Works in dev, staging, production, Docker, CI
- **Safe to commit**: No environment-specific paths
- **Zero maintenance**: Install once, works everywhere
- **Simple**: No glob patterns or complex path logic

### ENV Variable Strategy

The InfoTable engine sets ENV variables at Rails boot time:
```ruby
# lib/infotable/engine.rb
initializer "infotable.tailwind" do
  ENV["INFOTABLE_VIEWS_PATH"] = root.join("app/views/infotable").to_s
  ENV["INFOTABLE_FORMATTERS_PATH"] = root.join("lib/infotable/formatters").to_s
end
```

Tailwind v4 expands these ENV variables when building:
```css
@source "$INFOTABLE_VIEWS_PATH";
```
→ Expands to the actual gem path at build time

### Works Everywhere Automatically

The same CSS file works in all environments:
- **Development**: ENV variables point to your local gem location
- **Production**: ENV variables point to production gem location
- **CI/CD**: ENV variables point to CI gem location
- **Docker**: ENV variables point to container gem location

Rails `Infotable::Engine.root` always returns the correct path!

You can safely commit `infotable.css` to version control!

## Tailwind v3 (JS-based Config) - FALLBACK

If using Tailwind v3, the installer adds dynamic path resolution to your `tailwind.config.js`:

```javascript
const { execSync } = require('child_process');
const path = require('path');

// Helper to resolve gem path dynamically
function resolveGemPath(gemName) {
  try {
    const bundlerCmd = `bundle show ${gemName}`;
    const gemPath = execSync(bundlerCmd, { encoding: 'utf-8' }).trim();
    return gemPath;
  } catch (error) {
    console.warn(`Warning: Could not resolve ${gemName} gem path:`, error.message);
    return null;
  }
}

const infotableGemPath = resolveGemPath('infotable');

module.exports = {
  content: [
    './app/infotable/**/*.rb',
    ...(infotableGemPath ? [
      path.join(infotableGemPath, 'app/views/infotable/**/*.{erb,rb}'),
      path.join(infotableGemPath, 'app/assets/javascripts/infotable/**/*.js'),
      path.join(infotableGemPath, 'lib/infotable/formatters/**/*.rb'),
      path.join(infotableGemPath, 'app/components/**/*.{erb,rb}'),
    ] : []),
  ],
  // ... rest of config
}
```

This approach dynamically resolves the gem path at **build time** (every time Tailwind builds).

## Troubleshooting

### Styles Not Appearing

1. Check your Tailwind CSS file includes InfoTable @source directives
2. Verify gem path is correct: `bundle show infotable`
3. Update paths if needed: `rake infotable:update_tailwind_paths`
4. Rebuild: `rails tailwindcss:build`

### After Changing Gem Installation Method

If you switch from `path:` to `git:` or vice versa:

```bash
rake infotable:update_tailwind_paths
rails tailwindcss:build
```

## Why Different Approaches?

- **Tailwind v4**: @source doesn't support variables, so paths must be static and resolved at install time
- **Tailwind v3**: JavaScript config supports dynamic resolution via `execSync`, so paths are resolved at build time

Both approaches work reliably, but v4 is recommended for better Rails integration and performance.
