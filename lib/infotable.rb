require "rails-i18n"
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
    autoload :NumberFormatter, "infotable/formatters/number_formatter"
    autoload :TagsFormatter, "infotable/formatters/tags_formatter"
    autoload :TruncateFormatter, "infotable/formatters/truncate_formatter"
    autoload :ImageFormatter, "infotable/formatters/image_formatter"
    autoload :FilesizeFormatter, "infotable/formatters/filesize_formatter"
    autoload :DurationFormatter, "infotable/formatters/duration_formatter"

    # `formatter: :name` => class. Anything else is looked up as a custom "<Name>Formatter" constant.
    def self.built_in
      @built_in ||= {
        date: DateFormatter, datetime: DateFormatter,
        currency: CurrencyFormatter,
        boolean: BooleanFormatter,
        badge: BadgeFormatter, status: BadgeFormatter,
        action: ActionFormatter, actions: ActionFormatter,
        link: LinkFormatter, avatar: AvatarFormatter, percent: PercentFormatter,
        number: NumberFormatter, tags: TagsFormatter, list: TagsFormatter,
        truncate: TruncateFormatter, image: ImageFormatter,
        filesize: FilesizeFormatter, duration: DurationFormatter
      }.freeze
    end
  end

  # Returns the root path of the InfoTable gem
  def self.root
    Engine.root
  end

  # Returns paths that should be scanned by Tailwind CSS
  # For use with Node-based Tailwind (tailwind.config.js)
  def self.tailwind_content_paths
    [
      root.join("app/views/infotable/**/*.{erb,html,rb}").to_s,
      root.join("lib/infotable/formatters/**/*.rb").to_s,
      root.join("app/assets/javascripts/infotable/**/*.js").to_s
    ]
  end
end
