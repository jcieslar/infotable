module Infotable
  class Base
    class << self
      attr_accessor :table_columns, :table_query, :table_query_sql, :pagination_settings, :sort_settings, :height_settings, :infinite_scroll_settings, :row_link_settings, :row_attr_settings, :slim_rows_settings, :row_size_settings, :filters_button_settings, :display_settings, :nil_value_settings, :empty_value_settings, :table_authorize, :checkbox_settings, :batch_action_list, :countless_setting, :url_state_setting, :resizable_columns_setting

      def inherited(subclass)
        super
        subclass.table_columns = []
        subclass.pagination_settings = {
          per_page: Infotable.configuration.default_per_page,
          per_page_options: Infotable.configuration.per_page_options
        }
        subclass.sort_settings = {}
        subclass.height_settings = {
          min_height: nil, # nil means use global config
          max_height: nil, # nil means use global config
          fill_offset: nil # Integer when the table fills the viewport (table_height :fill)
        }
        subclass.infinite_scroll_settings = {
          enabled: false
        }
        subclass.row_attr_settings = { class: nil, data: nil }
        subclass.row_link_settings = {
          enabled: false,
          url: nil
        }
        subclass.slim_rows_settings = {
          enabled: false
        }
        subclass.row_size_settings = {
          size: :default # :slim, :mid, :default
        }
        subclass.filters_button_settings = {
          visible: true
        }
        subclass.display_settings = {
          title: nil,
          subtitle: nil
        }
        subclass.nil_value_settings = {
          value: nil # nil means use global config
        }
        subclass.empty_value_settings = {
          value: nil # nil means use global config
        }
        subclass.checkbox_settings = { enabled: false, id_method: :id }
        subclass.batch_action_list = []
        subclass.countless_setting = false
        subclass.url_state_setting = nil
        subclass.resizable_columns_setting = nil

        inherit_from_parent(subclass)
      end

      # Copy parent table definition so a subclass can extend it
      def inherit_from_parent(subclass)
        parent = subclass.superclass
        return if parent == Infotable::Base || parent.table_columns.nil?

        subclass.table_columns = parent.table_columns.map(&:dup)
        subclass.table_query = parent.table_query
        subclass.table_query_sql = parent.table_query_sql
        subclass.table_authorize = parent.table_authorize
        subclass.checkbox_settings = parent.checkbox_settings.dup
        subclass.batch_action_list = parent.batch_action_list.map(&:dup)
        subclass.countless_setting = parent.countless_setting
        subclass.url_state_setting = parent.url_state_setting
        subclass.resizable_columns_setting = parent.resizable_columns_setting
        subclass.instance_variable_set(:@toolbar_setting, parent.instance_variable_get(:@toolbar_setting))
        subclass.instance_variable_set(:@export_column_names, parent.instance_variable_get(:@export_column_names)&.dup)
        %i[pagination_settings sort_settings height_settings infinite_scroll_settings row_link_settings row_attr_settings
           slim_rows_settings row_size_settings filters_button_settings display_settings
           nil_value_settings empty_value_settings].each do |attr|
          subclass.public_send("#{attr}=", parent.public_send(attr).dup)
        end
      end

      # Define data source using ActiveRecord.
      # The block receives the controller (current_user, params, ...) for per-request scoping:
      #   query { |controller| Post.where(account: controller.current_account) }
      def query(&block)
        @table_query = block
      end

      # Skip SELECT COUNT(*) (slow on big tables): no total, no page numbers, only prev/next.
      def countless(enabled = true)
        @countless_setting = enabled
      end

      # Keep search, filters, sort and page in the page's address bar (shareable links, working Back
      # button). Default: Infotable.configuration.url_state. Turn it off for tables in modals/tabs
      # or when several unrelated tables should not fight over the URL.
      def url_state(enabled = true)
        @url_state_setting = enabled
      end

      # Drag handles on the column headers (and arrow keys on the focused handle) to change
      # column widths; widths are remembered per browser. Double-click resets one column.
      #   resizable_columns false
      def resizable_columns(enabled = true)
        @resizable_columns_setting = enabled
      end

      def resizable_columns?
        @resizable_columns_setting.nil? ? true : @resizable_columns_setting ? true : false
      end

      def url_state?
        @url_state_setting.nil? ? Infotable.configuration.url_state : @url_state_setting ? true : false
      end

      def countless?
        @countless_setting ? true : false
      end

      # Row checkboxes without bulk actions (e.g. to read the selection from your own JS)
      def checkbox_column(enabled: true, id_method: :id)
        @checkbox_settings = { enabled: enabled, id_method: id_method }
      end

      # Bulk actions; defining any turns the checkbox column on. See Infotable::BatchActions.
      def batch_actions(&block)
        builder = Infotable::BatchActions::Builder.new
        builder.instance_eval(&block)
        @batch_action_list = builder.actions
      end

      def checkbox_enabled?
        @checkbox_settings[:enabled] || @batch_action_list.any?
      end

      def checkbox_value(record)
        record.public_send(@checkbox_settings[:id_method])
      end

      # Ids of every row the query matches (the "select all matching" button), at most `limit`.
      # Plucks when the id method is a plain column of an ungrouped query, loads records otherwise.
      def checkbox_ids(query, limit = nil)
        method = @checkbox_settings[:id_method]
        # Without a cap the order is irrelevant (and costs a sort); with one, the table's own order
        # decides which rows make it in, so a capped selection is the first N rows the user sees
        scope = limit ? query.limit(limit) : query.reorder(nil)
        model = query.model

        if model.column_names.include?(method.to_s) && scope.group_values.empty? && scope.having_clause.empty?
          scope.pluck(model.arel_table[method])
        else
          scope.map { |record| checkbox_value(record) }
        end
      end

      # Per-table access check. Block receives the controller; falsy => 403.
      #   authorize { |controller| controller.current_user&.admin? }
      def authorize(&block)
        @table_authorize = block
      end

      def authorized?(context = nil)
        @table_authorize.nil? || @table_authorize.call(context) ? true : false
      end

      # Define data source using raw SQL
      # Raw SQL data source. The SQL becomes a sub-select aliased as the model's table, so
      # filters, search, sorting, pagination and export work like with `query`:
      #   query_sql "SELECT u.*, COUNT(p.id) AS posts_n FROM users u LEFT JOIN posts p ON ... GROUP BY u.id", model: User
      # The SQL is developer-defined (never interpolate request input into it).
      def query_sql(sql, model:)
        raise ArgumentError, "query_sql requires a model: (an ActiveRecord class used for types and the table alias)" unless model.respond_to?(:table_name)

        @table_query_sql = { sql: sql.to_s, model: model }
      end

      # Define a column
      COLUMN_OPTIONS = %i[label type sortable searchable filterable visible exportable pinned virtual virtual_sql
                          sql sort_sql value includes formatter formatter_options actions filter_type filter_options
                          filter_options_cache filter_options_limit filter_multi_select width].freeze

      def column(name, **options)
        @table_columns ||= []
        unknown = options.keys - COLUMN_OPTIONS
        if unknown.any? && defined?(Rails) && Rails.logger
          Rails.logger.warn("[Infotable] #{self.name || 'table'}: column :#{name} ignores unknown option(s) #{unknown.map(&:inspect).join(', ')}")
        end
        type = options[:type] || :string

        # Determine width - use custom if provided and not blank, otherwise use default
        width = if options[:width].present?
          options[:width]
        else
          default_column_width(type)
        end

        column_definition = {
          name: name,
          label: options[:label] || name.to_s.tr("_", " "),
          type: type,
          sortable: options.fetch(:sortable, false),
          searchable: options.fetch(:searchable, false),
          filterable: options.fetch(:filterable, false),
          visible: options.fetch(:visible, true),
          exportable: options.fetch(:exportable, !%i[action actions].include?(type)), # false keeps the column out of CSV exports
          pinned: options[:pinned], # :left, :right, or nil
          virtual: options.fetch(:virtual, false), # Virtual/computed columns (aggregates, subqueries)
          virtual_sql: options[:virtual_sql], # SQL expression for aggregate columns (used in HAVING clause)
          sql: options[:sql], # Row-level SQL expression for filtering/sorting (WHERE), e.g. "authors.name"
          sort_sql: options[:sort_sql], # Overrides :sql for ORDER BY only, e.g. filter by id, sort by name
          value: options[:value], # ->(record) { ... } reads the cell value when it is not a record attribute
          includes: options[:includes], # association(s) to preload for this column (avoids N+1), e.g. :author
          formatter: options[:formatter],
          formatter_options: options[:formatter_options],
          actions: options[:actions], # For action columns (deprecated - use formatter_options)
          filter_type: options[:filter_type],
          filter_options: options[:filter_options],
          filter_options_cache: options[:filter_options_cache], # e.g. 5.minutes: cache a Proc's result (not for per-user options)
          filter_options_limit: options[:filter_options_limit], # max <option>s rendered; default Infotable.configuration.max_filter_options
          filter_multi_select: options.fetch(:filter_multi_select, false),
          width: width
        }
        @table_columns << column_definition
      end

      # Get default width based on column type
      def default_column_width(type)
        case type
        when :boolean
          "80px"
        when :date
          "120px"
        when :datetime
          "180px"
        when :integer
          "100px"
        when :decimal, :float, :currency
          "120px"
        when :badge, :status
          "120px"
        when :action, :actions
          "100px"
        when :text
          "300px"
        when :string
          "200px"
        else
          "200px"
        end
      end

      # Set pagination per_page
      def per_page(value)
        @pagination_settings[:per_page] = value
      end

      # Set per_page options
      def per_page_options(values)
        @pagination_settings[:per_page_options] = values
      end

      # Set default sort
      def default_sort(column, direction = :asc)
        @sort_settings = { column: column, direction: direction }
      end

      # Set table minimum height
      def table_min_height(value)
        @height_settings[:min_height] = value
      end

      # Set table maximum height
      def table_max_height(value)
        @height_settings[:max_height] = value
      end

      # Size the table to the viewport: the rows area grows until the bottom of the table (and its
      # pagination) sits `offset` pixels above the bottom of the window, and follows window resizes.
      # table_min_height still applies as a floor. :fixed (default) uses table_max_height.
      # @example
      #   table_height :fill
      #   table_height :fill, offset: 32
      def table_height(mode, offset: 16)
        unless [ :fill, :fixed ].include?(mode)
          raise ArgumentError, "Invalid table height: #{mode}. Must be one of fill, fixed"
        end
        raise ArgumentError, "offset must be a non-negative Integer" unless offset.is_a?(Integer) && offset >= 0

        @height_settings[:fill_offset] = mode == :fill ? offset : nil
      end

      # Pixels to keep free below the table when it fills the viewport, nil for a fixed height
      def fill_offset
        @height_settings[:fill_offset]
      end

      def fill_height?
        !fill_offset.nil?
      end

      # Enable/disable infinite scroll
      def infinite_scroll(enabled)
        @infinite_scroll_settings[:enabled] = enabled
      end

      # Check if infinite scroll is enabled
      def infinite_scroll_enabled?
        @infinite_scroll_settings[:enabled]
      end

      # Configure row link
      # @param url [Proc, String] - URL generator (Proc receives record) or static URL
      # @example
      #   row_link ->(record) { "/comments/#{record.id}" }
      #   row_link "/posts/show"
      def row_link(url)
        @row_link_settings[:enabled] = true
        @row_link_settings[:url] = url
      end

      # Check if row link is enabled
      def row_link_enabled?
        @row_link_settings[:enabled]
      end

      # Get row link URL for a record
      def row_link_url(record)
        return nil unless row_link_enabled?

        url_generator = @row_link_settings[:url]
        if url_generator.is_a?(Proc)
          url_generator.call(record)
        else
          url_generator
        end
      end

      # Extra CSS classes per row: a String, or a Proc that receives the record (nil/false adds nothing).
      # Tailwind only generates classes it can see in your source, so write them out in full.
      # @example
      #   row_class ->(order) { "bg-red-50" if order.overdue? }
      def row_class(value = nil, &block)
        @row_attr_settings[:class] = value || block
      end

      def row_classes_for(record)
        setting = @row_attr_settings[:class]
        (setting.respond_to?(:call) ? setting.call(record) : setting).presence
      end

      # Extra data-* attributes per row: a Proc that receives the record and returns a Hash
      # ({ post_id: 1 } becomes data-post-id="1"). Handy for your own Stimulus controllers.
      # @example
      #   row_data ->(post) { { post_id: post.id, status: post.status } }
      def row_data(value = nil, &block)
        @row_attr_settings[:data] = value || block
      end

      def row_data_for(record)
        setting = @row_attr_settings[:data]
        data = setting.respond_to?(:call) ? setting.call(record) : setting
        data.is_a?(Hash) ? data : {}
      end

      # Clicking a row (not a link, button or input inside it) fires a cancelable
      # `infotable:row-click` event on the row (detail: { id, url, data }). If nothing calls
      # preventDefault() and the table has a row_link, the click falls back to following it.
      # @example
      #   row_click true
      def row_click(enabled = true)
        @row_link_settings[:click] = enabled ? true : false
      end

      def row_click?
        @row_link_settings[:click] ? true : false
      end

      # Rows react to clicks (row_link and/or row_click)
      def row_clickable?
        row_link_enabled? || row_click?
      end

      # Set row size (padding and text size)
      # @param size [Symbol] - Row size (:slim, :mid, :default)
      # @example
      #   row_size :slim
      #   row_size :mid
      #   row_size :default
      def row_size(size)
        valid_sizes = [ :slim, :mid, :default ]
        unless valid_sizes.include?(size)
          raise ArgumentError, "Invalid row size: #{size}. Must be one of #{valid_sizes.join(', ')}"
        end
        @row_size_settings ||= { size: :default }
        @row_size_settings[:size] = size

        # Also set slim_rows for backward compatibility
        @slim_rows_settings ||= { enabled: false }
        @slim_rows_settings[:enabled] = (size == :slim)
      end

      # Get current row size
      def row_size_value
        @row_size_settings ||= { size: :default }

        # Check slim_rows for backward compatibility
        if @slim_rows_settings && @slim_rows_settings[:enabled]
          return :slim
        end

        @row_size_settings[:size]
      end

      # Enable slim rows (compact padding) - DEPRECATED: Use row_size(:slim) instead
      # @example
      #   slim_rows true
      def slim_rows(enabled = true)
        @slim_rows_settings ||= { enabled: false }
        @slim_rows_settings[:enabled] = enabled

        # Also update row_size_settings for consistency
        @row_size_settings ||= { size: :default }
        @row_size_settings[:size] = enabled ? :slim : :default
      end

      # Check if slim rows is enabled - DEPRECATED: Use row_size_value instead
      def slim_rows_enabled?
        row_size_value == :slim
      end

      # Show/hide filters button
      # @param visible [Boolean] - Whether to show the filters button
      # @example
      #   show_filters_button false
      def show_filters_button(visible = true)
        @filters_button_settings ||= { visible: true }
        @filters_button_settings[:visible] = visible
      end

      # Where the controls live. :header (default) is the bar above the table with title, search,
      # export and filters buttons. :rail hides that bar and puts filters, columns, export and
      # refresh on a slim vertical rail at the table's right edge; search moves into the drawer.
      # @example
      #   toolbar :rail
      def toolbar(mode)
        unless [ :header, :rail ].include?(mode)
          raise ArgumentError, "Invalid toolbar: #{mode}. Must be one of header, rail"
        end
        @toolbar_setting = mode
      end

      def toolbar_mode
        @toolbar_setting || :header
      end

      def rail_toolbar?
        toolbar_mode == :rail
      end

      # Check if filters button is visible
      def filters_button_visible?
        @filters_button_settings ||= { visible: true }
        @filters_button_settings[:visible]
      end

      # Set table title
      # @param text [String] - The title to display above the table
      # @example
      #   table_title "User Management"
      def table_title(text)
        @display_settings ||= { title: nil, subtitle: nil }
        @display_settings[:title] = text
      end

      # Set table subtitle
      # @param text [String] - The subtitle to display below the title
      # @example
      #   table_subtitle "Manage all users in the system"
      def table_subtitle(text)
        @display_settings ||= { title: nil, subtitle: nil }
        @display_settings[:subtitle] = text
      end

      # Get table title
      def title
        @display_settings ||= { title: nil, subtitle: nil }
        @display_settings[:title]
      end

      # Get table subtitle
      def subtitle
        @display_settings ||= { title: nil, subtitle: nil }
        @display_settings[:subtitle]
      end

      # Set nil value placeholder
      # @param text [String] - The text to display for nil values
      # @example
      #   nil_value "N/A"
      #   nil_value ""
      def nil_value(text)
        @nil_value_settings ||= { value: nil }
        @nil_value_settings[:value] = text
      end

      # Get nil value placeholder (table-specific or global)
      def nil_value_placeholder
        @nil_value_settings ||= { value: nil }
        @nil_value_settings[:value].nil? ? Infotable.configuration.nil_value : @nil_value_settings[:value]
      end

      # Set empty value placeholder
      # @param text [String] - The text to display for empty strings
      # @example
      #   empty_value "N/A"
      #   empty_value ""
      def empty_value(text)
        @empty_value_settings ||= { value: nil }
        @empty_value_settings[:value] = text
      end

      # Get empty value placeholder (table-specific or global)
      def empty_value_placeholder
        @empty_value_settings ||= { value: nil }
        @empty_value_settings[:value].nil? ? Infotable.configuration.empty_value : @empty_value_settings[:value]
      end

      # Get minimum height (table-specific or global)
      def min_height
        @height_settings[:min_height] || Infotable.configuration.table_min_height
      end

      # Get maximum height (table-specific or global)
      def max_height
        @height_settings[:max_height] || Infotable.configuration.table_max_height
      end

      # Get the base query
      def base_query(context = nil)
        if @table_query
          @table_query.call(context)
        elsif @table_query_sql
          model = @table_query_sql[:model]
          model.from(Arel.sql("(#{@table_query_sql[:sql]}) AS #{model.connection.quote_table_name(model.table_name)}"))
        else
          raise Infotable::Error, "No query or query_sql defined for #{name}"
        end
      end

      # Raw cell value of a record for a column (value: proc, attribute or association)
      def cell_value(record, column)
        return column[:value].call(record) if column[:value]

        record.try(column[:name]) || record[column[:name]]
      end

      # Associations to preload for the table's columns (deduplicated)
      def preloads
        columns.flat_map { |col| Array.wrap(col[:includes]) }.uniq
      end

      # Get all columns
      def columns
        @table_columns || []
      end

      # Get virtual (computed/aggregated) columns
      def virtual_columns
        columns.select { |col| col[:virtual] }
      end

      # Get non-virtual (regular database) columns
      def regular_columns
        columns.reject { |col| col[:virtual] }
      end

      # Get visible columns
      def visible_columns
        columns.select { |col| col[:visible] }
      end

      # Columns a CSV export may contain (action columns and `exportable: false` are left out)
      def exportable_columns
        columns.select { |col| col[:exportable] }
      end

      # Which columns the CSV export contains and in which order, when the user has not chosen:
      #   export_columns :name, :email, :created_at
      # Without it the export uses the visible, exportable columns in table order. With it, the
      # list is also the pool the user can pick from (visible_columns can only narrow and reorder it).
      def export_columns(*names)
        @export_column_names = names.flatten.map(&:to_sym)
      end

      def export_column_names
        @export_column_names
      end

      # The columns to export, as column definitions in export order. `requested` is the list of
      # names the browser sends (the user's visible columns in their on-screen order).
      def columns_for_export(requested = nil)
        pool = exportable_columns
        pool = export_column_names.map { |name| pool.find { |col| col[:name] == name } || raise(ArgumentError, "export_columns: unknown or non-exportable column #{name.inspect} in #{self.name}") } if export_column_names

        by_name = pool.index_by { |col| col[:name].to_s }
        picked = Array(requested).map { |name| by_name[name.to_s] }.compact.uniq
        return picked if picked.any?

        export_column_names ? pool : pool.select { |col| col[:visible] }
      end

      # Get sortable columns
      def sortable_columns
        columns.select { |col| col[:sortable] }
      end

      # Get filterable columns
      def filterable_columns
        columns.select { |col| col[:filterable] }
      end

      # Get searchable columns
      def searchable_columns
        columns.select { |col| col[:searchable] }
      end
    end
  end
end
