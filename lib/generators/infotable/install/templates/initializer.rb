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

  # SECURITY: tables are served at /infotable/tables/:name/{data,export,ids}. The engine
  # controllers inherit from this controller, so authentication, locale, tenant scoping etc.
  # of your app also protect the tables. With the default (ActionController::Base) nothing
  # does: anyone can read and export every table that has no `authorize { ... }` block.
  config.parent_controller = "ApplicationController"

  # Mirror search, filters, sort and page in the address bar (shareable links, Back button)
  # config.url_state = true

  # Filter behavior: true = auto-apply filters (debounced, no Apply button), false = manual apply button
  config.autofilter = true
end
