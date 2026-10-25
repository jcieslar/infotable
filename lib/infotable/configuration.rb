module Infotable
  class Configuration
    attr_accessor :default_per_page,
                  :per_page_options,
                  :drawer_position,
                  :drawer_width,
                  :theme,
                  :turbo_enabled,
                  :pagination_gem,
                  :table_min_height,
                  :table_max_height,
                  :autofilter,
                  :nil_value,
                  :empty_value,
                  :parent_controller

    def initialize
      @default_per_page = 25
      @per_page_options = [ 10, 25, 50, 100 ]
      @drawer_position = :right # :left or :right
      @drawer_width = "26rem"
      @theme = :default # no effect yet (kept so existing initializers keep working)
      @turbo_enabled = true # no effect yet
      @pagination_gem = :pagy # no effect yet; Pagy is the only backend
      @table_min_height = "400px"
      @table_max_height = "600px"
      @autofilter = true # true = auto-apply filters (debounced), false = manual apply button
      @nil_value = "-" # Default placeholder for nil values
      @empty_value = "-" # Default placeholder for empty strings
      @parent_controller = "ActionController::Base" # Set to "ApplicationController" to inherit host auth/filters
    end
  end

  class << self
    attr_writer :configuration

    def configuration
      @configuration ||= Configuration.new
    end

    def configure
      yield(configuration)
    end

    def reset_configuration!
      @configuration = Configuration.new
    end
  end
end
