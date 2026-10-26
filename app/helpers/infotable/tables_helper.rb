module Infotable
  module TablesHelper
    # Main helper method to render an infotable
    # Usage: <%= infotable :users_table %>
    def infotable(table_name, **options, &block)
      table_class = resolve_table_class(table_name)

      # Merge options with defaults
      config = build_table_config(table_class, options)

      # Allow block configuration
      if block_given?
        yield config if block.arity > 0
      end

      # Build locals for partial
      locals = {
        table_name: table_name,
        table_class: table_class,
        config: config
      }

      # Only pass title/subtitle if explicitly provided
      locals[:title] = options[:title] if options.key?(:title)
      locals[:subtitle] = options[:subtitle] if options.key?(:subtitle)

      # Render the table frame
      render partial: "infotable/tables/table", locals: locals
    end

    # Inline width style for a header/body cell. Data columns are clipped to their width (ellipsis);
    # action columns hold buttons, so their width is only a minimum and the column grows to fit all
    # of them (a clipped "Delete" button is worse than a wider column).
    def infotable_cell_width_style(column, ellipsis: false)
      if %w[action actions].include?(column[:type].to_s)
        "width: 1%; min-width: #{column[:width]}; white-space: nowrap;"
      else
        "width: #{column[:width]}; max-width: #{column[:width]}; overflow: hidden;#{' text-overflow: ellipsis;' if ellipsis}"
      end
    end

    # Format cell value based on column definition
    def format_cell_value(record, column, table_class = nil)
      value = (table_class || Infotable::Base).cell_value(record, column)

      # If formatter is provided, use it (formatters handle nil values themselves)
      if column[:formatter]
        if column[:formatter].is_a?(Proc)
          # Execute formatter proc with value and record
          return instance_exec(value, record, &column[:formatter])
        elsif column[:formatter].is_a?(Symbol)
          # Use named formatter
          return placeholder_for(value, column, table_class) ||
                 format_with_named_formatter(value, record, column)
        elsif column[:formatter].is_a?(Hash)
          # Formatter with options: { type: :badge, options: {...} }
          formatter_type = column[:formatter][:type]
          formatter_options = column[:formatter][:options] || {}
          return format_with_named_formatter(value, record, column.merge(formatter: formatter_type, formatter_options: formatter_options))
        end
      end

      # Return nil placeholder for nil values (except for types that handle nil specially)
      if value.nil? && table_class && ![ :boolean, :action ].include?(column[:type])
        return table_class.nil_value_placeholder
      end

      # Return empty placeholder for empty strings (except for types that handle empty specially)
      if value.is_a?(String) && value.empty? && table_class && ![ :boolean, :action ].include?(column[:type])
        return table_class.empty_value_placeholder
      end

      # Default formatting based on type
      case column[:type]
      when :datetime
        format_datetime(value)
      when :date
        format_date(value)
      when :boolean
        format_boolean(value, column)
      when :currency
        format_currency(value, column)
      when :badge
        format_badge(value, column)
      when :action
        format_actions(value, record, column)
      else
        value.to_s
      end
    end

    private

    def resolve_table_class(table_name)
      Infotable::TableResolver.resolve(table_name)
    end

    def build_table_config(table_class, options)
      ActiveSupport::OrderedOptions.new.merge!({
        per_page: options[:per_page] || table_class.pagination_settings[:per_page],
        per_page_options: options[:per_page_options] || table_class.pagination_settings[:per_page_options],
        drawer_position: options[:drawer_position] || Infotable.configuration.drawer_position,
        drawer_width: options[:drawer_width] || Infotable.configuration.drawer_width,
        theme: options[:theme] || Infotable.configuration.theme,
        autofilter: options.fetch(:autofilter, Infotable.configuration.autofilter)
      })
    end

    # nil / "" placeholders for named formatters, which would otherwise each
    # render their own idea of "nothing" (BooleanFormatter and ActionFormatter handle it themselves)
    def placeholder_for(value, column, table_class)
      return unless table_class
      return if %i[boolean action actions avatar].include?(column[:type]) || %i[boolean action actions avatar].include?(column[:formatter])

      return table_class.nil_value_placeholder if value.nil?
      table_class.empty_value_placeholder if value.is_a?(String) && value.empty?
    end

    def format_with_named_formatter(value, record, column)
      formatter_name = column[:formatter]
      formatter_options = column[:formatter_options] || {}

      formatter_class = case formatter_name
      when :date, :datetime
        Infotable::Formatters::DateFormatter
      when :currency
        Infotable::Formatters::CurrencyFormatter
      when :boolean
        Infotable::Formatters::BooleanFormatter
      when :badge, :status
        Infotable::Formatters::BadgeFormatter
      when :action, :actions
        Infotable::Formatters::ActionFormatter
      when :link
        Infotable::Formatters::LinkFormatter
      when :avatar
        Infotable::Formatters::AvatarFormatter
      when :percent
        Infotable::Formatters::PercentFormatter
      else
        # Custom formatter: :avatar => AvatarFormatter (or Namespaced::AvatarFormatter)
        "#{formatter_name.to_s.camelize}Formatter".safe_constantize ||
          raise(Infotable::Error, "Unknown formatter :#{formatter_name} for column :#{column[:name]}. " \
                                  "Built-ins: date, currency, boolean, badge, action, link, avatar, percent; custom: define #{formatter_name.to_s.camelize}Formatter.")
      end

      formatter_class.new(self).format(value, record, formatter_options)
    end

    # Default formatters for types
    def format_datetime(value)
      return "" if value.blank?
      formatter = Infotable::Formatters::DateFormatter.new(self)
      formatter.format(value, nil, format: :datetime)
    end

    def format_date(value)
      return "" if value.blank?
      formatter = Infotable::Formatters::DateFormatter.new(self)
      formatter.format(value, nil, format: :short)
    end

    def format_boolean(value, column)
      formatter = Infotable::Formatters::BooleanFormatter.new(self)
      formatter.format(value, nil, column[:formatter_options] || {})
    end

    def format_currency(value, column)
      return "" if value.blank?
      formatter = Infotable::Formatters::CurrencyFormatter.new(self)
      formatter.format(value, nil, column[:formatter_options] || {})
    end

    def format_badge(value, column)
      return "" if value.blank?
      formatter = Infotable::Formatters::BadgeFormatter.new(self)
      formatter.format(value, nil, column[:formatter_options] || {})
    end

    def format_actions(value, record, column)
      formatter = Infotable::Formatters::ActionFormatter.new(self)
      formatter.format(value, record, column[:formatter_options] || column[:actions] || {})
    end

    # Route helpers for engine routes
    def infotable_table_path(options = {})
      Infotable::Engine.routes.url_helpers.table_path(options)
    end

    def infotable_table_data_path(options = {})
      Infotable::Engine.routes.url_helpers.table_data_path(options)
    end

    def infotable_table_export_path(options = {})
      Infotable::Engine.routes.url_helpers.table_export_path(options)
    end

    INITIAL_STATE_KEYS = %w[search sort sort_column sort_direction page per_page filters].freeze

    # Table state carried by the host page's own URL as `?users_table[search]=x&users_table[page]=2`
    # (written by the table controller). Only known keys and plain values survive; the data
    # endpoint validates them again when the frame loads.
    def infotable_initial_state(table_name)
      raw = params[table_name.to_s]
      return {} unless raw.respond_to?(:to_unsafe_h)

      raw.to_unsafe_h.slice(*INITIAL_STATE_KEYS).each_with_object({}) do |(key, value), state|
        clean = sanitize_state_value(value)
        state[key.to_sym] = clean unless clean.nil? || clean == ""
      end
    end

    # Helper to build table URL params while preserving current state
    # This ensures sorting, pagination, and other state is maintained across interactions
    def table_url_params(new_params = {})
      base_params = {
        table_name: params[:table_name],
        sort_column: scalar_request_param(:sort_column),
        sort_direction: scalar_request_param(:sort_direction),
        sort: scalar_request_param(:sort),
        page: scalar_request_param(:page),
        per_page: scalar_request_param(:per_page)
      }
      base_params[:search] = params[:search] if params[:search].is_a?(String) && params[:search].present?
      base_params[:filters] = params[:filters].to_unsafe_h if params[:filters].respond_to?(:to_unsafe_h) && params[:filters].present?

      base_params.compact.merge(new_params)
    end

    def sanitize_state_value(value, depth = 0)
      case value
      when String then value.delete("\u0000")[0, 500]
      when Array then depth < 3 ? value.first(50).filter_map { sanitize_state_value(_1, depth + 1) }.select { _1.is_a?(String) } : nil
      when Hash then depth < 3 ? value.first(50).to_h { |k, v| [ k.to_s[0, 100], sanitize_state_value(v, depth + 1) ] }.compact : nil
      end
    end

    DRAWER_WIDTH_FORMAT = /\A\d+(\.\d+)?(px|rem|em|vw|%)\z/
    DEFAULT_DRAWER_WIDTH = "26rem".freeze

    # HTML attributes for the slide-in drawer (side and width from config)
    # `rail`: the drawer sits flush against the rail, so no rounded corners or heavy shadow
    def infotable_drawer_attributes(config, rail: false)
      side = config.drawer_position.to_s == "left" ? "left" : "right"
      width = config.drawer_width.to_s.match?(DRAWER_WIDTH_FORMAT) ? config.drawer_width.to_s : DEFAULT_DRAWER_WIDTH
      hidden = side == "left" ? "-100%" : "100%"

      # With a rail the drawer must line up with the card's inner edge: inset it by the card's 1px border
      inset = rail ? "1px" : "0"
      {
        style: "#{side}: #{inset}; #{"top: 1px; bottom: 1px; " if rail}width: #{width}; max-width: 90%; transform: translateX(#{hidden});",
        class: "absolute top-0 bottom-0 bg-white dark:bg-gray-900 #{side == 'left' ? 'border-r' : 'border-l'}#{side == 'left' ? (rail ? ' rounded-l-[11px]' : ' rounded-r-xl') : (rail ? ' rounded-r-[11px]' : ' rounded-l-xl')} border-gray-200 dark:border-gray-700 #{rail ? 'shadow-none' : 'shadow-xl'} transition-all duration-300 ease-in-out z-50",
        role: "dialog",
        inert: true, # closed drawer is off-screen: keep it out of the tab order (JS toggles it)
        aria: { label: I18n.t("infotable.drawer.label"), hidden: true },
        data: { infotable__drawer_target: "drawer", drawer_side: side }
      }
    end

    BATCH_BUTTON_COLORS = {
      default: "border-gray-300 dark:border-gray-600 bg-white dark:bg-gray-900 text-gray-700 dark:text-gray-300 hover:bg-gray-50 dark:hover:bg-gray-800",
      primary: "border-indigo-600 bg-indigo-600 text-white hover:bg-indigo-700",
      success: "border-green-600 bg-green-600 text-white hover:bg-green-700",
      warning: "border-yellow-500 bg-yellow-500 text-white hover:bg-yellow-600",
      danger: "border-red-600 bg-red-600 text-white hover:bg-red-700"
    }.freeze

    NUMBER_OP_SYMBOLS = { "eq" => "=", "neq" => "\u2260", "gt" => ">", "gte" => "\u2265", "lt" => "<", "lte" => "\u2264" }.freeze

    # The filters and search that are narrowing the table right now, as chips:
    #   [{ name: "age", type: "number", label: "Age", text: "\u2265 45" }, { search: true, text: "..." }]
    # Only filterable columns with something to apply are listed; blank inputs are not active.
    def infotable_active_filters(table_class, filters, search = nil)
      filters = filters.to_unsafe_h if filters.respond_to?(:to_unsafe_h)
      filters = {} unless filters.is_a?(Hash)
      filters = filters.with_indifferent_access

      chips = table_class.filterable_columns.filter_map do |column|
        params = filters[column[:name]]
        type = filter_type_for_column(column)
        text = infotable_filter_chip_text(type, params)
        next if text.blank?

        { name: column[:name].to_s, type: type, label: column[:label].to_s, text: text }
      end

      chips.unshift(search: true, text: t("infotable.filters.active.search", query: search)) if search.present?
      chips
    end

    def infotable_filter_chip_text(type, params)
      case type
      when "select", "boolean"
        raw = params.is_a?(Hash) ? params[:value] : params
        values = Array(raw).flatten.reject { |v| v.is_a?(Hash) || v.blank? }.map(&:to_s)
        return if values.empty?

        values.map { |v| type == "boolean" ? infotable_boolean_chip_text(v) : v }.join(", ")
      else
        return unless params.is_a?(Hash)

        op = params[:op].to_s
        return t("infotable.filters.text_ops.#{op}") if %w[is_empty is_not_empty].include?(op)

        value = params[:value].is_a?(String) ? params[:value].strip : nil
        from = params[:from].is_a?(String) ? params[:from].strip : nil
        to = params[:to].is_a?(String) ? params[:to].strip : nil

        if type == "text"
          return if value.blank?

          "#{t("infotable.filters.text_ops.#{op.presence_in(%w[contains exact not_contain starts_with ends_with]) || 'contains'}")} \u201c#{value}\u201d"
        elsif op.present? && op != "between" && value.present?
          type == "number" ? "#{NUMBER_OP_SYMBOLS.fetch(op, op)} #{value}" : "#{t("infotable.filters.date_ops.#{op}", default: op)} #{value}"
        elsif from.present? && to.present?
          "#{from} \u2013 #{to}"
        elsif from.present?
          "\u2265 #{from}"
        elsif to.present?
          "\u2264 #{to}"
        end
      end
    end

    def infotable_boolean_chip_text(value)
      key = { "true" => "true", "false" => "false", "is_empty" => "empty", "is_not_empty" => "not_empty" }[value]
      key ? t("infotable.filters.boolean.#{key}") : value
    end

    def infotable_batch_button_classes(color)
      "inline-flex items-center px-3 py-1.5 border text-sm font-medium rounded-lg transition-colors #{BATCH_BUTTON_COLORS.fetch(color, BATCH_BUTTON_COLORS[:default])}"
    end

    # Query params are user input: only plain strings are echoed back into links
    def scalar_request_param(key)
      value = params[key]
      value.is_a?(String) ? value : nil
    end

    # [[column, direction], ...] currently applied, for header indicators
    def current_sorts
      @sorts || []
    end

    # Page numbers to link to: first, last and two either side of the current page.
    # (Pagy's #series is protected since Pagy 43, and gaps were never rendered anyway.)
    def infotable_page_window(pagy, around: 2)
      last = pagy.last.to_i
      ([ 1, last ] + ((pagy.page - around)..(pagy.page + around)).to_a).select { |n| n.between?(1, last) }.uniq.sort
    end

    # DOM id for a filter control, scoped by table so two tables on one page
    # with the same column names do not collide (labels, getElementById).
    def infotable_filter_id(table_name, column, suffix)
      "filter_#{table_name}_#{column[:name]}_#{suffix}"
    end

    # [options, total] for a select filter. The Proc runs in the view (so it can use helpers),
    # the result is cut to the column's `filter_options_limit` (default
    # Infotable.configuration.max_filter_options) and, with `filter_options_cache: 5.minutes`,
    # cached per table and column. Do not cache options that depend on the current user.
    def infotable_filter_options(table_class, column)
      source = column[:filter_options]
      options = if source.is_a?(Proc)
        ttl = column[:filter_options_cache]
        if ttl
          key = [ "infotable", "filter_options", table_class&.name || table_class.object_id, column[:name].to_s ]
          Rails.cache.fetch(key, expires_in: ttl) { instance_exec(&source).to_a }
        else
          instance_exec(&source).to_a
        end
      else
        source.to_a
      end

      limit = column[:filter_options_limit] || Infotable.configuration.max_filter_options
      [ limit ? options.first(limit) : options, options.size ]
    end

    # Per-page choices for the selector: the table's own options plus the current limit
    def per_page_choices(table_class, current)
      (table_class.pagination_settings[:per_page_options].to_a + [ current ]).compact.map(&:to_i).uniq.sort
    end

    # Determine which filter partial to render based on column type and filter_type
    def filter_type_for_column(column)
      # Explicit filter_type takes precedence
      return column[:filter_type].to_s if column[:filter_type]

      # Otherwise infer from column type
      case column[:type]
      when :string, :text
        "text"
      when :boolean
        "boolean"
      when :integer, :float, :decimal, :number
        "number"
      when :date, :datetime
        "date"
      when :select
        "select"
      else
        "text" # default to text filter
      end
    end
  end
end
