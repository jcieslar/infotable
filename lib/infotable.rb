require "infotable/version"
require "infotable/configuration"
require "infotable/engine"

module Infotable
  class Error < StandardError; end

  # Autoload core components
  autoload :Base, "infotable/base"
  autoload :FilterProcessor, "infotable/filter_processor"
  autoload :BatchActions, "infotable/batch_actions"
  autoload :SearchProcessor, "infotable/search_processor"
  autoload :Sql, "infotable/sql"
  autoload :TableResolver, "infotable/table_resolver"

  # Formatters
  module Formatters
    autoload :BaseFormatter, "infotable/formatters/base_formatter"
    autoload :DateFormatter, "infotable/formatters/date_formatter"
    autoload :CurrencyFormatter, "infotable/formatters/currency_formatter"
    autoload :BooleanFormatter, "infotable/formatters/boolean_formatter"
    autoload :BadgeFormatter, "infotable/formatters/badge_formatter"
    autoload :ActionFormatter, "infotable/formatters/action_formatter"
    autoload :LinkFormatter, "infotable/formatters/link_formatter"
    autoload :AvatarFormatter, "infotable/formatters/avatar_formatter"
    autoload :PercentFormatter, "infotable/formatters/percent_formatter"
  end

  # Returns the root path of the InfoTable gem
  def self.root
    Engine.root
  end
end
