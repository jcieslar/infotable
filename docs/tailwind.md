# Tailwind CSS Setup for InfoTable

This document explains how InfoTable integrates with Tailwind CSS in Rails applications.

## Overview

InfoTable **requires** the `tailwindcss-rails` gem (Tailwind CSS v4):
- Uses `@source` directives with dynamically resolved gem paths
- Paths are auto-generated **before every Tailwind build**
- Works in all environments (development, staging, production, Docker, CI)
- The generated file is **NOT committed to git** - it regenerates for each environment

## How It Works

### Dynamic Path Generation

InfoTable uses Rake task hooks to generate gem paths before Tailwind builds:

```
app/assets/stylesheets/
├── application.tailwind.css    # Your main CSS file
└── infotable.css               # InfoTable ENV variable references
```

**1. Installer creates placeholder file**:
```css
/* infotable.css - Placeholder */
/* This file is auto-generated before Tailwind builds */
@source "../../app/infotable";
```

**2. Rake task runs before Tailwind builds**:
```bash
# Automatically runs before:
rails tailwindcss:build   # Manual builds
rails tailwindcss:watch   # Development watching
rake assets:precompile    # Production deploys
```

**3. Rake task generates actual paths for current environment**:
```css
/* infotable.css - Generated */
@source "../../app/infotable";
@source "/current/environment/gem/path/app/views/infotable";
@source "/current/environment/gem/path/lib/infotable/formatters";
```

**4. application.tailwind.css imports it**:
```css
@import "tailwindcss";
@import './infotable';
```

### Why This Approach?

1. **Always correct**: Paths generated from Rails engine before EVERY build
2. **Environment-agnostic**: Works in dev, staging, production, Docker, CI
3. **NOT committed**: File regenerates for each environment automatically
4. **Simple**: No glob patterns, no manual configuration needed
5. **Works with all gem installation methods**:
   - `gem 'infotable'` (RubyGems)
   - `gem 'infotable', path: '../infotable'` (local development)
   - `gem 'infotable', git: '...'` (git repository)
   - Bundler vendor bundles
6. **Automatic**: Zero manual intervention - hooks handle everything

## Installation

```bash
rails generate infotable:install
```

This will:
1. Create `app/assets/stylesheets/infotable.css` (placeholder)
2. Add `@import './infotable'` to your main Tailwind CSS file
3. Add `infotable.css` to `.gitignore`
4. Configure Rake task hooks

Then build (paths generate automatically):
```bash
rails tailwindcss:build
```

The first time you run `tailwindcss:build`, the Rake task will generate the actual gem paths for your current environment.

## How It Works in Each Environment

### Development
```bash
# Start development server
bin/dev  # or rails server

# If you need to rebuild Tailwind manually:
rails tailwindcss:build  # Rake task runs first, generates paths, then Tailwind builds
```

### Production / Deployment
```bash
# During deployment (e.g., Heroku, Kamal, Capistrano):
rake assets:precompile  # Rake task runs first, generates production paths, then compiles

# Or if using tailwindcss-rails in production:
rails tailwindcss:build  # Rake task runs first automatically
```

### Manual Regeneration (Optional)

You typically **don't need** to run this manually, but if you want to regenerate:

```bash
rake infotable:generate_tailwind_sources
```

**Note:** The file regenerates automatically before every Tailwind build.

## Troubleshooting

### Styles Not Appearing

1. **Check the import exists**:
   ```bash
   grep -r "@import.*infotable" app/assets/stylesheets/
   ```

2. **Verify infotable.css was created**:
   ```bash
   cat app/assets/stylesheets/infotable.css
   ```

3. **Check gem is installed**:
   ```bash
   bundle show infotable
   ```

4. **Rebuild Tailwind**:
   ```bash
   rails tailwindcss:build
   ```

5. **Check Tailwind is watching** (in development):
   ```bash
   # Make sure bin/dev or foreman is running
   # Or manually: rails tailwindcss:watch
   ```

### After Gem Updates

The glob patterns work automatically. Just rebuild:

```bash
bundle update infotable
rails tailwindcss:build
```

No need to regenerate paths - they're environment-agnostic!

## Technical Details

### How Path Generation Works

InfoTable generates the CSS file with actual gem paths resolved at build time:

**Step 1: At Install Time**
```bash
rails generate infotable:install
```

The installer finds the gem path using `Bundler.load.specs` and writes it to `infotable.css`:
```css
@source "/Users/you/.rbenv/.../gems/infotable-1.0.0/app/views/infotable";
@source "/Users/you/.rbenv/.../gems/infotable-1.0.0/lib/infotable/formatters";
```

**Step 2: Before Deployment**

The Rake task `infotable:generate_tailwind_sources` runs **automatically** before `assets:precompile`:
```ruby
# lib/tasks/infotable.rake
Rake::Task["assets:precompile"].enhance(["infotable:generate_tailwind_sources"])
```

This regenerates the CSS file with production gem paths:
```css
@source "/usr/local/bundle/gems/infotable-1.0.0/app/views/infotable";
@source "/usr/local/bundle/gems/infotable-1.0.0/lib/infotable/formatters";
```

**Step 3: Tailwind Builds**
```bash
rails tailwindcss:build
```

Tailwind scans the actual gem paths to find and compile Tailwind classes.

### Why This Works Everywhere

- **Development**: Generated at install with local gem path
- **Production**: Auto-regenerated before deployment with production gem path
- **Docker**: Regenerated during container build
- **CI**: Regenerated during CI build process

The Rake hook ensures paths are **always correct** for the current environment!

## Rake Tasks

```bash
# Regenerate Tailwind paths (rarely needed, runs automatically before assets:precompile)
rake infotable:generate_tailwind_sources

# Alias for backwards compatibility
rake infotable:update_tailwind_paths
```

## Best Practices

1. **Use `tailwindcss-rails` gem** (required for InfoTable)
2. **Commit `infotable.css`** to version control (paths regenerate on deploy)
3. **Let the Rake hook handle deployment** (automatic path regeneration)
4. **Manually regenerate** only if changing gem installation method (path: → gem, etc.)

## Migration from Previous Versions

If you have an old setup with ENV variables or manual paths:

1. Run the updated installer:
   ```bash
   rails generate infotable:install
   ```

2. This will regenerate `infotable.css` with actual resolved paths

3. Remove any old `@source` directives from `application.tailwind.css`

4. Keep only the `@import './infotable'` line in your main CSS file

5. Rebuild Tailwind:
   ```bash
   rails tailwindcss:build
   ```

**Old (using ENV variables - no longer used):**
```css
/* infotable.css */
@source "$INFOTABLE_VIEWS_PATH";
@source "$INFOTABLE_FORMATTERS_PATH";
```

**New (using actual paths - current approach):**
```css
/* infotable.css */
@source "/actual/gem/path/app/views/infotable";
@source "/actual/gem/path/lib/infotable/formatters";
```
