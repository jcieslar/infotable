require "json"

module Infotable
  module Generators
    class InstallGenerator < Rails::Generators::Base
      source_root File.expand_path("templates", __dir__)

      desc "Install InfoTable into your application"

      def check_tailwindcss_rails_gem
        begin
          gem_spec = Bundler.load.specs.find { |s| s.name == "tailwindcss-rails" }

          if gem_spec.nil?
            say "\n" + "=" * 60, :red
            say "❌ ERROR: tailwindcss-rails gem not found", :red
            say "=" * 60, :red
            say "\nInfoTable requires the tailwindcss-rails gem to be installed.", :yellow
            say "This gem provides Tailwind CSS v4 support for Rails applications.\n", :yellow
            say "To install, add to your Gemfile:", :cyan
            say "  gem 'tailwindcss-rails'", :green
            say "\nThen run:", :cyan
            say "  bundle install", :green
            say "  rails tailwindcss:install", :green
            say "\nAfter installing tailwindcss-rails, run this installer again:", :cyan
            say "  rails generate infotable:install", :green
            say "\n" + "=" * 60, :red
            exit 1
          end

          say "✅ Found tailwindcss-rails gem (version #{gem_spec.version})", :green
        rescue => e
          say "⚠️  Could not verify tailwindcss-rails gem: #{e.message}", :yellow
          say "   Continuing with installation...", :yellow
        end
      end

      def detect_js_bundler
        @js_bundler = if File.exist?("config/importmap.rb")
          :importmap
        elsif File.exist?("esbuild.config.js") || package_json_has?("esbuild")
          :esbuild
        elsif File.exist?("vite.config.ts") || package_json_has?("vite")
          :vite
        elsif File.exist?("webpack.config.js") || package_json_has?("webpack")
          :webpack
        else
          :unknown
        end

        say "Detected JavaScript bundler: #{@js_bundler}", :green
      end

      def add_routes
        route 'mount Infotable::Engine => "/infotable"'
      end

      def create_infotable_directory
        empty_directory "app/infotable"
        create_file "app/infotable/.keep"
      end

      def setup_javascript
        case @js_bundler
        when :importmap
          setup_importmap
        when :esbuild, :webpack, :vite
          setup_bundler
        else
          say "⚠️  Could not detect JavaScript bundler. Please see manual setup instructions.", :yellow
        end
      end

      def setup_tailwind
        # Check for Tailwind CSS file from tailwindcss-rails gem
        if File.exist?("app/assets/stylesheets/application.tailwind.css") ||
           File.exist?("app/assets/tailwind/application.css")
          say "✅ Detected Tailwind CSS configuration", :green
          append_tailwind_v4_sources
        else
          say "\n" + "=" * 60, :yellow
          say "⚠️  Tailwind CSS file not found", :yellow
          say "=" * 60, :yellow
          say "\nInfoTable requires tailwindcss-rails to be installed and configured.", :yellow
          say "\nPlease run:", :cyan
          say "  rails tailwindcss:install", :green
          say "\nThis will create the required Tailwind CSS configuration.", :cyan
          say "After that, run this installer again:", :cyan
          say "  rails generate infotable:install", :green
          say "\n" + "=" * 60, :yellow
          exit 1
        end
      end

      def create_initializer
        template "initializer.rb", "config/initializers/infotable.rb"
      end

      def create_sync_script
        template "sync-infotable-gem.sh", "bin/sync-infotable-gem.sh"
        chmod "bin/sync-infotable-gem.sh", 0755
        say "   ✅ Created bin/sync-infotable-gem.sh (for vendored gems)", :green
      end

      def add_to_gitignore
        gitignore_entry = "# InfoTable - Generated from ERB template, do not commit\napp/assets/stylesheets/infotable.css\napp/assets/tailwind/infotable.css\n"

        if File.exist?(".gitignore")
          content = File.read(".gitignore")
          unless content.include?("infotable.css")
            append_to_file ".gitignore", "\n#{gitignore_entry}"
            say "   ✅ Added generated infotable.css to .gitignore", :green
          else
            say "   ℹ️  infotable.css already in .gitignore", :blue
          end
        else
          create_file ".gitignore", gitignore_entry
          say "   ✅ Created .gitignore with infotable.css", :green
        end

        say "   📝 Commit infotable.css.erb (the template), not infotable.css (generated)", :cyan
      end

      def show_post_install_message
        say "\n" + "=" * 60, :green
        say "✅ InfoTable installation complete!", :green
        say "=" * 60, :green
        say "\nNext steps:", :cyan
        say "1. Rebuild your assets:", :yellow

        if @js_bundler == :esbuild
          say "   npm run build", :green
        elsif @js_bundler == :webpack
          say "   npm run build", :green
        elsif @js_bundler == :vite
          say "   npm run build", :green
        end

        say "   rails tailwindcss:build", :green

        say "\n2. Verify Tailwind CSS is loaded in your layout:", :yellow
        say "   Ensure your application layout includes:", :cyan
        say "   <%= stylesheet_link_tag \"tailwind\", \"data-turbo-track\": \"reload\" %>", :green

        say "\n3. Restart your Rails server", :yellow
        say "4. Create your first table definition in app/infotable/", :yellow
        say "5. Use <%= infotable :your_table_name %> in your views", :yellow

        say "\n" + "=" * 60, :cyan
        say "💡 Important Notes:", :cyan
        say "=" * 60, :cyan
        say "• InfoTable requires the tailwindcss-rails gem", :green
        say "• infotable.css.erb is processed by Rake task before Tailwind builds", :green
        say "• Gem paths resolve dynamically for each environment (dev/production)", :green
        say "• Commit infotable.css.erb (template), gitignore infotable.css (generated)", :cyan

        # Show vendored gem note if using path:
        if gem_is_vendored?
          say "\n" + "=" * 60, :yellow
          say "📦 Vendored Gem Detected:", :yellow
          say "=" * 60, :yellow
          say "• Use symlink for development: ln -s /path/to/gem vendor/gems/infotable", :cyan
          say "• Before deploying, sync the gem: bin/sync-infotable-gem.sh", :green
          say "• The script copies files (Docker can't follow symlinks)", :cyan
        end

        say "\n📖 Documentation: https://github.com/jcieslar/infotable", :cyan
      end

      private

      def setup_importmap
        say "Configuring for importmap...", :green
        # Importmap pins are handled by the engine's importmap.rb
      end

      def setup_bundler
        say "Configuring for #{@js_bundler}...", :green

        # Find the infotable gem path
        gem_path = find_gem_path

        case @js_bundler
        when :esbuild
          setup_esbuild(gem_path)
        when :webpack
          setup_webpack(gem_path)
        when :vite
          setup_vite(gem_path)
        else
          say "⚠️  Unknown bundler. Please configure manually.", :yellow
        end
      end

      def setup_esbuild(gem_path)
        # Check for required peer dependencies
        ensure_npm_dependencies

        # Add import for InfoTable controllers from asset paths
        if File.exist?("app/javascript/controllers/index.js")
          content = File.read("app/javascript/controllers/index.js")

          # Check if InfoTable controllers are already registered
          unless content.include?("infotable")
            # Check if application is already imported
            unless content.match?(/from\s+['"]\.\/application['"]/)
              inject_into_file "app/javascript/controllers/index.js", after: /import.*\n/ do
                "import { application } from \"./application\"\n"
              end
            end

            js_content = <<~JS

// InfoTable Stimulus controllers (resolved from Rails asset paths)
import InfoTableTableController from "infotable/controllers/table_controller"
import InfoTableDrawerController from "infotable/controllers/drawer_controller"
application.register("infotable--table", InfoTableTableController)
application.register("infotable--drawer", InfoTableDrawerController)
            JS

            append_to_file "app/javascript/controllers/index.js", js_content
            say "   ✅ Added InfoTable controllers to controllers/index.js", :green
          else
            say "   ℹ️  InfoTable controllers already registered in controllers/index.js", :blue
          end
        elsif File.exist?("app/javascript/application.js")
          content = File.read("app/javascript/application.js")

          unless content.include?("infotable")
            # Find the application instance in application.js
            application_var = if content.include?("const application")
              "application"
            elsif content.include?("export { application }")
              "application"
            else
              "Stimulus.Application.start()"
            end

            js_content = <<~JS

// InfoTable Stimulus controllers (resolved from Rails asset paths)
import InfoTableTableController from "infotable/controllers/table_controller"
import InfoTableDrawerController from "infotable/controllers/drawer_controller"
#{application_var}.register("infotable--table", InfoTableTableController)
#{application_var}.register("infotable--drawer", InfoTableDrawerController)
            JS

            append_to_file "app/javascript/application.js", js_content
            say "   ✅ Added InfoTable controllers to application.js", :green
          else
            say "   ℹ️  InfoTable controllers already registered in application.js", :blue
          end
        else
          say "   ⚠️  Could not find controllers/index.js or application.js", :yellow
          say "   Please manually import InfoTable controllers", :yellow
        end

        say "✅ esbuild configured successfully", :green
      end

      def setup_webpack(gem_path)
        # Check for required peer dependencies
        ensure_npm_dependencies

        # Add import for InfoTable controllers from asset paths
        if File.exist?("app/javascript/controllers/index.js")
          content = File.read("app/javascript/controllers/index.js")

          unless content.include?("infotable")
            # Check if application is already imported
            unless content.match?(/from\s+['"]\.\/application['"]/)
              inject_into_file "app/javascript/controllers/index.js", after: /import.*\n/ do
                "import { application } from \"./application\"\n"
              end
            end

            js_content = <<~JS

// InfoTable Stimulus controllers (resolved from Rails asset paths)
import InfoTableTableController from "infotable/controllers/table_controller"
import InfoTableDrawerController from "infotable/controllers/drawer_controller"
application.register("infotable--table", InfoTableTableController)
application.register("infotable--drawer", InfoTableDrawerController)
            JS

            append_to_file "app/javascript/controllers/index.js", js_content
            say "   ✅ Added InfoTable controllers to controllers/index.js", :green
          else
            say "   ℹ️  InfoTable controllers already registered", :blue
          end
        elsif File.exist?("app/javascript/application.js")
          content = File.read("app/javascript/application.js")

          unless content.include?("infotable")
            # Find the application instance in application.js
            application_var = if content.include?("const application")
              "application"
            elsif content.include?("export { application }")
              "application"
            else
              "Stimulus.Application.start()"
            end

            js_content = <<~JS

// InfoTable Stimulus controllers (resolved from Rails asset paths)
import InfoTableTableController from "infotable/controllers/table_controller"
import InfoTableDrawerController from "infotable/controllers/drawer_controller"
#{application_var}.register("infotable--table", InfoTableTableController)
#{application_var}.register("infotable--drawer", InfoTableDrawerController)
            JS

            append_to_file "app/javascript/application.js", js_content
            say "   ✅ Added InfoTable controllers to application.js", :green
          else
            say "   ℹ️  InfoTable controllers already registered", :blue
          end
        end

        say "✅ webpack configured successfully", :green
      end

      def setup_vite(gem_path)
        # Check for required peer dependencies
        ensure_npm_dependencies

        # Add import for InfoTable controllers from asset paths
        if File.exist?("app/javascript/controllers/index.js")
          content = File.read("app/javascript/controllers/index.js")

          unless content.include?("infotable")
            # Check if application is already imported
            unless content.match?(/from\s+['"]\.\/application['"]/)
              inject_into_file "app/javascript/controllers/index.js", after: /import.*\n/ do
                "import { application } from \"./application\"\n"
              end
            end

            js_content = <<~JS

// InfoTable Stimulus controllers (resolved from Rails asset paths)
import InfoTableTableController from "infotable/controllers/table_controller"
import InfoTableDrawerController from "infotable/controllers/drawer_controller"
application.register("infotable--table", InfoTableTableController)
application.register("infotable--drawer", InfoTableDrawerController)
            JS

            append_to_file "app/javascript/controllers/index.js", js_content
            say "   ✅ Added InfoTable controllers to controllers/index.js", :green
          else
            say "   ℹ️  InfoTable controllers already registered", :blue
          end
        elsif File.exist?("app/javascript/application.js")
          content = File.read("app/javascript/application.js")

          unless content.include?("infotable")
            # Find the application instance in application.js
            application_var = if content.include?("const application")
              "application"
            elsif content.include?("export { application }")
              "application"
            else
              "Stimulus.Application.start()"
            end

            js_content = <<~JS

// InfoTable Stimulus controllers (resolved from Rails asset paths)
import InfoTableTableController from "infotable/controllers/table_controller"
import InfoTableDrawerController from "infotable/controllers/drawer_controller"
#{application_var}.register("infotable--table", InfoTableTableController)
#{application_var}.register("infotable--drawer", InfoTableDrawerController)
            JS

            append_to_file "app/javascript/application.js", js_content
            say "   ✅ Added InfoTable controllers to application.js", :green
          else
            say "   ℹ️  InfoTable controllers already registered", :blue
          end
        end

        say "✅ vite configured successfully", :green
      end

      def create_vite_config(gem_path)
        return if File.exist?("vite.config.ts") || File.exist?("vite.config.js")

        vite_config = <<~JS
          import { defineConfig } from 'vite'
          import RubyPlugin from 'vite-plugin-ruby'

          export default defineConfig({
            plugins: [RubyPlugin()],
            resolve: {
              alias: {
                'infotable': '#{gem_path}/app/assets/javascripts/infotable'
              }
            }
          })
        JS

        create_file "vite.config.ts", vite_config
        say "   Created vite.config.ts with infotable alias", :green
      end

      def should_create_vite_config?
        !File.exist?("vite.config.ts") && !File.exist?("vite.config.js")
      end

      def ensure_npm_dependencies
        # Only check for bundlers that require npm packages
        return unless [ :esbuild, :webpack, :vite ].include?(@js_bundler)

        unless File.exist?("package.json")
          say "   ⚠️  No package.json found", :yellow
          say "   📝 You'll need to install npm dependencies manually", :cyan
          return
        end

        package_json = JSON.parse(File.read("package.json"))
        package_json["dependencies"] ||= {}
        package_json["devDependencies"] ||= {}

        missing_deps = []
        missing_tailwind_deps = []

        # Check for required peer dependencies
        unless package_json["dependencies"]["@hotwired/stimulus"] || package_json["devDependencies"]["@hotwired/stimulus"]
          missing_deps << "@hotwired/stimulus"
        end

        unless package_json["dependencies"]["sortablejs"] || package_json["devDependencies"]["sortablejs"]
          missing_deps << "sortablejs"
        end

        # Check for Tailwind plugin (recommended, not required)
        unless package_json["dependencies"]["@tailwindcss/forms"] || package_json["devDependencies"]["@tailwindcss/forms"]
          missing_tailwind_deps << "@tailwindcss/forms"
        end

        if missing_deps.any?
          say "\n" + "=" * 60, :red
          say "❌ ERROR: Missing required npm dependencies", :red
          say "=" * 60, :red
          say "\nInfoTable requires the following npm packages:", :yellow
          missing_deps.each do |dep|
            say "  • #{dep}", :yellow
          end
          say "\nThese are required for esbuild/webpack/vite to bundle the controllers.", :cyan
          say "\nInstall them by running:", :cyan

          package_manager = if File.exist?("yarn.lock")
            "yarn add @hotwired/stimulus sortablejs"
          elsif File.exist?("pnpm-lock.yaml")
            "pnpm add @hotwired/stimulus sortablejs"
          else
            "npm install @hotwired/stimulus sortablejs"
          end

          say "  #{package_manager}", :green
          say "\nAfter installing, restart your dev server.", :cyan
          say "=" * 60, :red
          exit 1
        else
          say "   ✅ All required npm dependencies are installed", :green
        end

        if missing_tailwind_deps.any?
          say "   ℹ️  Recommended Tailwind plugins:", :cyan
          missing_tailwind_deps.each do |dep|
            say "      - #{dep}", :cyan
          end
          say "   Install with: npm install -D @tailwindcss/forms", :cyan
        end

      rescue JSON::ParserError => e
        say "⚠️  Could not parse package.json: #{e.message}", :yellow
      end

      def add_controller_registration
        # This method is no longer needed with npm package approach
      end

      def find_gem_path
        # Use Bundler to find the gem path - works with path:, git:, and rubygems installs
        if defined?(Bundler)
          begin
            spec = Bundler.load.specs.find { |s| s.name == "infotable" }
            return spec.full_gem_path if spec
          rescue => e
            say "   ⚠️  Could not find gem via Bundler: #{e.message}", :yellow
          end
        end

        # Fallback to Gem::Specification
        begin
          spec = Gem::Specification.find_by_name("infotable")
          spec.gem_dir
        rescue Gem::MissingSpecError
          # Last resort: use relative path from generator location
          File.expand_path("../../..", __dir__)
        end
      end

      def append_tailwind_v4_sources
        tailwind_file = if File.exist?("app/assets/stylesheets/application.tailwind.css")
          "app/assets/stylesheets/application.tailwind.css"
        elsif File.exist?("app/assets/tailwind/application.css")
          "app/assets/tailwind/application.css"
        else
          say "   ⚠️  Tailwind CSS file not found", :yellow
          return
        end

        # Create separate infotable.css file with resolved gem paths
        create_infotable_css_file

        # Tailwind only scans the gem's views if the main CSS imports the generated file
        content = File.read(tailwind_file)
        if content.match?(/@import\s+["']\.?\/?infotable["']/)
          say "   ℹ️  InfoTable import already exists in #{File.basename(tailwind_file)}", :blue
        else
          if content.include?("@import \"tailwindcss\"")
            inject_into_file tailwind_file, after: /@import\s+["']tailwindcss["'];?\s*\n/ do
              "\n/* InfoTable - Requires tailwindcss-rails gem */\n@import './infotable';\n"
            end
          else
            prepend_to_file tailwind_file, "/* InfoTable - Requires tailwindcss-rails gem */\n@import './infotable';\n\n"
          end

          say "   ✅ Added @import './infotable' to #{File.basename(tailwind_file)}", :green
        end

        say "   📝 Run: rails tailwindcss:build", :cyan
      end

      def create_infotable_css_file
        # Determine the stylesheets directory
        stylesheets_dir = if File.exist?("app/assets/stylesheets")
          "app/assets/stylesheets"
        elsif File.exist?("app/assets/tailwind")
          "app/assets/tailwind"
        else
          "app/assets/stylesheets"
        end

        infotable_css_path = File.join(stylesheets_dir, "infotable.css.erb")

        # Create ERB file that dynamically resolves gem paths
        css_content = <<~CSS
          /* InfoTable Tailwind Sources - ERB Template */
          /* Requires: tailwindcss-rails gem (https://github.com/rails/tailwindcss-rails) */
          /* Paths are resolved dynamically via ERB from Infotable module */

          /* Local table definitions in your Rails app */
          @source "../../app/infotable";

          /* InfoTable gem paths (resolved via ERB at build time) */
          @source "<%= Infotable.views_path %>";
          @source "<%= Infotable.formatters_path %>";
        CSS

        create_file infotable_css_path, css_content

        say "   ✅ Created #{infotable_css_path} with ERB templates", :green
        say "   📝 Gem paths resolve dynamically via Infotable module", :cyan
        say "   📝 Works in all environments automatically", :green
      end

      def package_json_has?(package)
        return false unless File.exist?("package.json")

        package_json = JSON.parse(File.read("package.json"))
        (package_json["dependencies"]&.key?(package) ||
         package_json["devDependencies"]&.key?(package))
      rescue JSON::ParserError
        false
      end

      def gem_is_vendored?
        return false unless defined?(Bundler)

        begin
          spec = Bundler.load.specs.find { |s| s.name == "infotable" }
          # Check if gem is installed via path: (vendored)
          spec&.source&.class&.name == "Bundler::Source::Path"
        rescue => e
          false
        end
      end
    end
  end
end
