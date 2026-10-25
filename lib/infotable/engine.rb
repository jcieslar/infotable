require "turbo-rails"
require "stimulus-rails"
require "pagy"

module Infotable
  class Engine < ::Rails::Engine
    isolate_namespace Infotable

    # Configure engine
    config.infotable = ActiveSupport::OrderedOptions.new

    # Default configuration values
    config.infotable.table_min_height = "400px"
    config.infotable.table_max_height = "600px"

    # Rails already adds the engine's app/assets/* directories to the asset path;
    # only the precompile list is needed. Skipped for apps without an asset pipeline.
    initializer "infotable.assets" do |app|
      if app.config.respond_to?(:assets)
        app.config.assets.precompile += %w[infotable/controllers/*.js]
      end
    end

    # Setup Stimulus controllers for importmap (only runs if importmap-rails is installed)
    initializer "infotable.importmap", before: "importmap" do |app|
      if app.config.respond_to?(:importmap)
        app.config.importmap.paths << root.join("config/importmap.rb") if root.join("config/importmap.rb").exist?
      end
    end

    # Add helpers to host application
    initializer "infotable.helpers" do
      ActiveSupport.on_load(:action_controller_base) do
        helper Infotable::Engine.helpers
      end
    end

    # Load engine i18n locale files
    initializer "infotable.i18n" do |app|
      config.i18n.load_path += Dir[root.join("config/locales/**/*.yml")]
    end

    # Expose gem paths via ENV variables for Tailwind CSS v4 @source directives
    # This allows Tailwind to scan the gem's views/formatters at build time
    # Works in development, production, Docker, CI - everywhere!
    initializer "infotable.tailwind", before: :load_config_initializers do
      ENV["INFOTABLE_VIEWS_PATH"] = root.join("app/views/infotable").to_s
      ENV["INFOTABLE_FORMATTERS_PATH"] = root.join("lib/infotable/formatters").to_s
    end
  end
end
