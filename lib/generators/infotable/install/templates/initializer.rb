# InfoTable Configuration
# For more configuration options, see: https://github.com/jcieslar/infotable

Infotable.configure do |config|
  # Default number of items per page
  config.default_per_page = 25

  # Available per-page options
  config.per_page_options = [ 10, 25, 50, 100 ]

  # Filter drawer position (:left or :right)
  config.drawer_position = :right

  # Drawer width
  config.drawer_width = "26rem" # px, rem, em, vw or %

  # Controller the engine controllers inherit from. Use your app's controller so
  # authentication, locale, tenant scoping etc. also protect the tables:
  # config.parent_controller = "ApplicationController"

  # Filter behavior: true = auto-apply filters (debounced, no Apply button), false = manual apply button
  config.autofilter = true
end
