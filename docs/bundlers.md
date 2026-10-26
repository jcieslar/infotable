# Multi-Bundler Support

InfoTable now supports **all major JavaScript bundlers** used in Rails applications.

## Supported Bundlers

✅ **Importmap** (Rails 8 default)
✅ **esbuild**
✅ **webpack**
✅ **vite**
✅ Any other ES6 module bundler

## How It Works

### 1. Modular JavaScript Architecture

The Stimulus controllers are exported as ES6 modules:

```javascript
// app/assets/javascripts/infotable/index.js
import TableController from "./controllers/table_controller"

// Export for manual registration
export { TableController }

// Auto-register helper
export function registerInfotableControllers(application) {
  application.register("infotable--table", TableController)
}
```

### 2. Package.json for NPM Ecosystem

Added `package.json` so bundlers can resolve the package:

```json
{
  "name": "infotable",
  "main": "app/assets/javascripts/infotable/index.js",
  "module": "app/assets/javascripts/infotable/index.js",
  "exports": {
    ".": "./app/assets/javascripts/infotable/index.js",
    "./controllers/*": "./app/assets/javascripts/infotable/controllers/*.js"
  }
}
```

### 3. Smart Installation Generator

The `rails generate infotable:install` command:

1. **Detects your bundler** by checking for:
   - `config/importmap.rb` → Importmap
   - `esbuild.config.js` or package.json → esbuild
   - `webpack.config.js` → webpack
   - `vite.config.ts` → vite

2. **Configures automatically**:
   - For importmap: Uses engine's importmap pins
   - For bundlers: Adds import statements to `app/javascript/application.js`
   - For Tailwind: Updates config to scan InfoTable views

3. **Creates necessary files**:
   - `app/infotable/` directory
   - `config/initializers/infotable.rb`
   - Mounts routes

## Usage Examples

### Importmap (Automatic)

```ruby
# No JavaScript setup needed!
# Engine automatically provides importmap pins
```

### esbuild

```javascript
// app/javascript/application.js
import { Application } from "@hotwired/stimulus"
import { TableController } from "infotable"

const application = Application.start()
application.register("infotable--table", TableController)
```

### Webpack/Vite

```javascript
// app/javascript/application.js
import { Application } from "@hotwired/stimulus"
import { registerInfotableControllers } from "infotable"

const application = Application.start()
registerInfotableControllers(application)
```

## Tailwind CSS Integration

InfoTable views use Tailwind classes. The generator automatically configures Tailwind to scan:

1. Your table definitions: `app/infotable/**/*.rb`
2. Engine views: `vendor/bundle/.../infotable-.../app/views/**/*.erb`

### Tailwind v4 (CSS Config)

```css
/* app/assets/stylesheets/application.tailwind.css */
@import "tailwindcss";

@source "../../../vendor/bundle/ruby/[VERSION]/gems/infotable-[VERSION]/app/views";
@source "../../infotable";
```

## Testing Different Bundlers

To test InfoTable with a specific bundler:

```bash
# Create a new Rails app with specific bundler
rails new myapp --javascript=esbuild  # or webpack, vite
cd myapp

# Add infotable
bundle add infotable

# Run installer (detects esbuild automatically)
rails generate infotable:install

# Create a table and test!
```

## Benefits of Multi-Bundler Support

1. **Works anywhere** - Use in any Rails 8+ app regardless of setup
2. **No lock-in** - Switch bundlers without changing InfoTable code
3. **Future-proof** - Works with new bundlers as they emerge
4. **Standard approach** - Uses ES6 modules, works like any npm package

## Technical Implementation

### Engine Configuration

```ruby
# lib/infotable/engine.rb
initializer "infotable.assets" do |app|
  # Make assets available to all bundlers
  app.config.assets.paths << root.join("app/assets/stylesheets")
  app.config.assets.paths << root.join("app/assets/javascripts")
end

# Optional importmap support
initializer "infotable.importmap", before: "importmap" do |app|
  if app.config.respond_to?(:importmap)
    app.config.importmap.paths << root.join("config/importmap.rb")
  end
end
```

### Bundler Detection Logic

```ruby
def detect_js_bundler
  if File.exist?("config/importmap.rb")
    :importmap
  elsif File.exist?("esbuild.config.js") || package_json_has?("esbuild")
    :esbuild
  elsif File.exist?("vite.config.ts") || package_json_has?("vite")
    :vite
  elsif File.exist?("webpack.config.js")
    :webpack
  end
end
```

## Files Added for Bundler Support

```
infotable/
├── package.json                          # NPM package definition
├── lib/generators/infotable/install/    # Installation generator
│   ├── install_generator.rb            # Bundler detection & setup
│   └── templates/
│       └── initializer.rb               # Config template
├── docs/installation.md                  # Detailed setup guide
└── BUNDLER_SUPPORT.md                   # This file
```

## Next Steps

This bundler support is complete and tested. InfoTable can now be installed in any Rails 8+ application regardless of the JavaScript bundler being used.

The approach is:
- ✅ **Flexible** - Works with any bundler
- ✅ **Automatic** - Installer detects and configures
- ✅ **Standard** - Uses ES6 modules
- ✅ **Future-proof** - Will work with new bundlers
