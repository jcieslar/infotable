# InfoTable Installation Guide

InfoTable works with any Rails 8+ application regardless of your JavaScript bundler setup.

## Quick Installation

### Step 1: Add the Gem

Add to your `Gemfile`:

```ruby
gem 'infotable'
```

Then run:

```bash
bundle install
```

### Step 2: Run the Installer

The installer will automatically detect your setup and configure accordingly:

```bash
rails generate infotable:install
```

This will:
- ✅ Mount the engine routes
- ✅ Create `app/infotable/` directory for your table definitions
- ✅ Detect your JavaScript bundler and configure it
- ✅ Configure Tailwind CSS (if present) to scan InfoTable views
- ✅ Create an initializer for configuration

### Step 3: Install Tailwind CSS (if not already installed)

InfoTable uses Tailwind CSS for styling. If you don't have it:

```bash
bundle add tailwindcss-rails
rails tailwindcss:install
```

## Manual Setup (by Bundler)

### Importmap (Rails Default)

The engine automatically configures importmap. No additional JavaScript setup needed!

**Verify your `config/importmap.rb` includes:**

```ruby
# This is added automatically by the engine
pin "infotable", to: "infotable/index.js"
pin_all_from Infotable::Engine.root.join("app/assets/javascripts/infotable/controllers"),
  under: "controllers/infotable",
  to: "infotable/controllers"
```

### esbuild

The installer automatically configures esbuild! It will:
- ✅ Add direct imports for InfoTable controllers
- ✅ Update `app/javascript/controllers/index.js` or `app/javascript/application.js`
- ✅ Check for required npm dependencies

**What the installer adds:**

To your `app/javascript/controllers/index.js`:
```javascript
// InfoTable Stimulus controllers
import "/path/to/gem/app/assets/javascripts/infotable/controllers/table_controller.js"
import "/path/to/gem/app/assets/javascripts/infotable/controllers/drawer_controller.js"
```

**How it works:**

esbuild doesn't have native glob support, so we import the controllers directly from the gem path. The controllers are automatically registered with your Stimulus application.

**Required npm dependencies:**
```bash
npm install @hotwired/stimulus sortablejs
```

### Webpack

The installer automatically configures webpack using `require.context`:

**Added to `app/javascript/controllers/index.js`:**
```javascript
// InfoTable Stimulus controllers
const infotableControllers = require.context("/path/to/gem/app/assets/javascripts/infotable/controllers", true, /_controller\.js$/)
infotableControllers.keys().forEach(infotableControllers)
```

**How it works:**

Webpack's `require.context` dynamically imports all controller files from the gem directory. This is the recommended Rails 7+ pattern for loading Stimulus controllers from engines.

**Required npm dependencies:**
```bash
npm install @hotwired/stimulus sortablejs
```

### Vite

The installer automatically configures Vite using `import.meta.glob`:

**Added to `app/javascript/controllers/index.js`:**
```javascript
// InfoTable Stimulus controllers
import.meta.glob("../../../../path/to/gem/app/assets/javascripts/infotable/controllers/**/*_controller.js", { eager: true })
```

**How it works:**

Vite's `import.meta.glob` dynamically imports all controller files from the gem directory using a relative path. The `eager: true` option ensures controllers are loaded immediately.

**Required npm dependencies:**
```bash
npm install @hotwired/stimulus sortablejs
```

**Benefits of these approaches:**
- ✅ No stimulus-loading dependency needed
- ✅ Controllers stay in the gem and auto-update
- ✅ Standard Rails 7+ pattern for bundlers
- ✅ Direct, explicit loading with no magic

## Tailwind CSS Configuration

InfoTable uses **pure Tailwind CSS** - no custom CSS required! The installer automatically configures Tailwind to scan the gem's views.

### Tailwind v4 (Rails 8+ default with tailwindcss-rails)

**What the installer does automatically:**

The installer detects Tailwind v4 and adds `@source` directives to your Tailwind CSS file (`app/assets/tailwind/application.css` or `app/assets/stylesheets/application.tailwind.css`):

```css
@import "tailwindcss";

/* InfoTable gem - Added by InfoTable installer */
@source "../../infotable";
@source "/path/to/gem/app/views/infotable";
@source "/path/to/gem/app/assets/javascripts/infotable";
@source "/path/to/gem/lib/infotable/formatters";
```

**After installation:**

1. Rebuild Tailwind:
```bash
rails tailwindcss:build
```

2. Verify your layout loads Tailwind CSS:
```erb
<!-- In app/views/layouts/application.html.erb -->
<%= stylesheet_link_tag "tailwind", "data-turbo-track": "reload" %>
```

### Tailwind v3 (JavaScript config)

**What the installer does automatically:**

For Tailwind v3, the installer adds gem paths to your Tailwind config (`config/tailwind.config.js` or `tailwind.config.js`):

```javascript
module.exports = {
  content: [
    './app/views/**/*.html.erb',
    './app/helpers/**/*.rb',
    './app/javascript/**/*.js',
    './app/infotable/**/*.rb',  // Your table definitions
    '/path/to/gem/app/views/infotable/**/*.{erb,rb}',  // Gem views
    '/path/to/gem/app/assets/javascripts/infotable/**/*.js',  // Gem JavaScript (for dynamic classes)
    '/path/to/gem/lib/infotable/formatters/**/*.rb',  // Gem formatters
  ],
  // ... rest of config
}
```

**After installation:**

Rebuild Tailwind:
```bash
rails tailwindcss:build
```

## Routes Configuration

The installer adds this to `config/routes.rb`:

```ruby
Rails.application.routes.draw do
  mount Infotable::Engine => "/infotable"

  # Your routes...
end
```

## Configuration

Customize InfoTable in `config/initializers/infotable.rb`:

```ruby
Infotable.configure do |config|
  config.default_per_page = 25
  config.per_page_options = [10, 25, 50, 100]
  config.drawer_position = :right  # or :left
  config.drawer_width = "400px"
  config.theme = :default
  config.turbo_enabled = true
end
```

## Verification

After installation, rebuild your assets and test:

```bash
# If using esbuild/webpack/vite
npm run build

# If using Tailwind
rails tailwindcss:build

# Restart your Rails server
rails server
```

Then create a test table:

1. **Create a test table definition** in `app/infotable/test_table.rb`:

```ruby
class TestTable < Infotable::Base
  query { User.all }

  column :id, label: "ID", type: :integer, sortable: true
  column :name, label: "Name", type: :string, sortable: true

  per_page 10
end
```

2. **Add to a view**:

```erb
<%= infotable :test_table %>
```

3. **Visit the page** - you should see a fully styled, interactive table!

### Organizing Tables in Folders

You can organize your table definitions in subfolders. Rails' Zeitwerk autoloader automatically creates namespaces from the directory structure:

```ruby
# app/infotable/cms/users_table.rb
class Cms::UsersTable < Infotable::Base
  query { User.all }
  column :id, sortable: true
  column :name, sortable: true
  per_page 25
end

# Use in views:
<%= infotable :cms_users_table %>
```

Or with deeper nesting:

```ruby
# app/infotable/cms/admins/users_table.rb
class Cms::Admins::UsersTable < Infotable::Base
  query { User.where(admin: true) }
  column :id, sortable: true
  column :name, sortable: true
  per_page 25
end

# Use in views:
<%= infotable :cms_admins_users_table %>
```

**Important:** With Rails' Zeitwerk autoloader, the directory structure provides the namespace automatically. Don't wrap classes in `module` blocks - use the `class Cms::UsersTable` syntax instead.

## Troubleshooting

### Styles not loading (no shadows, no hover effects)

This is the most common issue! It means Tailwind CSS is either:
1. Not configured to scan InfoTable's views
2. Not rebuilt after installation
3. Not loaded in your layout

**Fix steps:**

1. **Rebuild Tailwind:**
```bash
rails tailwindcss:build
```

2. **Verify your layout loads Tailwind CSS:**

Your `app/views/layouts/application.html.erb` should include:
```erb
<%= stylesheet_link_tag "tailwind", "data-turbo-track": "reload" %>
```
or
```erb
<%= stylesheet_link_tag "application", "data-turbo-track": "reload" %>
```

3. **Check Tailwind configuration:**

**For Tailwind v4** (Rails 8+ with tailwindcss-rails):
- Open `app/assets/tailwind/application.css` or `app/assets/stylesheets/application.tailwind.css`
- Verify it includes:
  ```css
  @source "../../infotable";
  @source "/path/to/gem/app/views/infotable";
  @source "/path/to/gem/app/assets/javascripts/infotable";
  @source "/path/to/gem/lib/infotable/formatters";
  ```

**For Tailwind v3** (JavaScript config):
- Open `config/tailwind.config.js` or `tailwind.config.js`
- Verify the `content` array includes:
  - `'./app/infotable/**/*.rb'` (your table definitions)
  - `'/path/to/gems/infotable-x.x.x/app/views/infotable/**/*.{erb,rb}'` (gem views)
  - `'/path/to/gems/infotable-x.x.x/app/assets/javascripts/infotable/**/*.js'` (gem JavaScript - **important for dynamic classes**)
  - `'/path/to/gems/infotable-x.x.x/lib/infotable/formatters/**/*.rb'` (gem formatters)

4. **Restart your Rails server**

**Note:** InfoTable uses pure Tailwind CSS with no custom stylesheets. All styling (shadows, hover effects, colors) comes from Tailwind utility classes, so proper Tailwind configuration is essential.

### JavaScript not loading

**For esbuild:**
- Check browser console for import errors
- Verify `controllers/index.js` or `application.js` contains direct imports:
  ```javascript
  import "/path/to/gem/app/assets/javascripts/infotable/controllers/table_controller.js"
  import "/path/to/gem/app/assets/javascripts/infotable/controllers/drawer_controller.js"
  ```
- Rebuild JavaScript: `npm run build`
- Ensure required dependencies are installed: `npm install @hotwired/stimulus sortablejs`

**For webpack:**
- Check browser console for import errors
- Verify `controllers/index.js` contains:
  ```javascript
  const infotableControllers = require.context("path/to/gem/...", true, /_controller\.js$/)
  infotableControllers.keys().forEach(infotableControllers)
  ```
- Rebuild JavaScript: `npm run build`
- Ensure required dependencies are installed: `npm install @hotwired/stimulus sortablejs`

**For vite:**
- Check browser console for import errors
- Verify `controllers/index.js` contains:
  ```javascript
  import.meta.glob("path/to/gem/**/*_controller.js", { eager: true })
  ```
- Rebuild JavaScript: `npm run build`
- Ensure required dependencies are installed: `npm install @hotwired/stimulus sortablejs`

**For Importmap:**
- Check `bin/importmap json` to see if infotable is pinned
- The engine automatically configures importmap

### Filters button doesn't work

- Make sure JavaScript is loading (check console)
- Ensure Stimulus is properly initialized
- Rebuild assets and restart server

### Route errors

- Verify engine is mounted in `config/routes.rb`
- Check `rails routes | grep infotable`

## Next Steps

See the [README](../README.md) for creating tables, formatters and advanced features.
