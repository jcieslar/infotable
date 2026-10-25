# InfoTable Configuration
# Configure global settings for all InfoTable tables

Infotable.configure do |config|
  # Default number of items per page
  # config.default_per_page = 25

  # Available options for per-page selector
  # config.per_page_options = [10, 25, 50, 100]

  # Table height settings (can be overridden per table)
  # Accepts any valid CSS height value (px, rem, vh, etc.)
  config.table_min_height = "400px"
  config.table_max_height = "600px"

  # Filter drawer settings
  # config.drawer_position = :right  # :left or :right
  # config.drawer_width = "400px"

  # Enable/disable Turbo
  # config.turbo_enabled = true
end
