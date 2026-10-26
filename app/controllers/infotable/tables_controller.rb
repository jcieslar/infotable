module Infotable
  class TablesController < ApplicationController
    include Pagy::Method

    before_action :load_table_class
    before_action :authorize_table

    # A value PostgreSQL cannot represent (e.g. an id filter of 10**40) is a bad request, not a crash
    rescue_from ActiveRecord::RangeError do
      render plain: "Parameter out of range", status: :bad_request
    end
    before_action :set_params

    def show
      process_table_request
      render_table_frame
    end

    def data
      process_table_request

      respond_to do |format|
        format.html {
          # Always render the full frame
          render_table_frame
        }
        format.turbo_stream {
          # For infinite scroll - return turbo stream to append rows and replace pagination frame
          # Following the guide's "Frames + Streams" pattern
          if @page_out_of_range # nothing left: appending the first page again would repeat its rows
            return render turbo_stream: turbo_stream.replace("#{params[:table_name]}_pagination", partial: "infotable/tables/end_indicator")
          end

          streams = [
            turbo_stream.append(
              "#{params[:table_name]}_tbody",
              partial: "infotable/tables/table_rows",
              locals: {
                records: @records,
                table_class: @table_class
              }
            )
          ]

          # Replace the pagination frame with the next one (or end indicator)
          if @pagy.next
            streams << turbo_stream.replace(
              "#{params[:table_name]}_pagination",
              partial: "infotable/tables/next_page_frame"
            )
          else
            # No more pages - replace with end indicator
            streams << turbo_stream.replace(
              "#{params[:table_name]}_pagination",
              partial: "infotable/tables/end_indicator"
            )
          end

          render turbo_stream: streams
        }
      end
    end

    # Ids of every row matching the current filters and search, for "select all matching".
    # Same authorization and query as the table; capped by Infotable.configuration.max_select_all.
    def ids
      return head :not_found unless @table_class.checkbox_enabled?

      cap = Infotable.configuration.max_select_all
      ids = @table_class.checkbox_ids(build_query, cap && cap + 1)
      truncated = cap && ids.size > cap
      ids = ids.first(cap) if truncated

      render json: { ids: ids.map(&:to_s), truncated: truncated ? true : false }
    end

    def export
      require "csv"

      # Process the same query as show/data but without pagination
      @query = build_query

      # The browser sends the user's visible columns in their on-screen order; the table decides
      # what may be exported (see Base.columns_for_export)
      requested = scalar_param(:visible_columns).to_s.split(",").map(&:strip)
      visible_columns = @table_class.columns_for_export(requested)

      # Set CSV headers for streaming download
      headers["Content-Type"] = "text/csv; charset=utf-8"
      headers["Content-Disposition"] = "attachment; filename=\"#{params[:table_name].to_s.gsub(/[^\w-]/, '')}_#{Time.current.strftime('%Y%m%d_%H%M%S')}.csv\""
      headers["Last-Modified"] = Time.current.httpdate
      headers["Cache-Control"] = "no-cache"
      headers["X-Accel-Buffering"] = "no" # Disable buffering for nginx
      headers["X-Content-Type-Options"] = "nosniff"

      # Stream CSV response
      self.response_body = Enumerator.new do |y|
        # Write header row
        header_row = visible_columns.map { |col| col[:label] }
        y << CSV.generate_line(header_row)

        # Write data rows using find_each for memory efficiency
        # Batched with OFFSET so the requested ORDER BY is kept (find_each ignores it)
        offset = 0
        loop do
          batch = @query.limit(EXPORT_BATCH_SIZE).offset(offset).to_a
          batch.each do |record|
            row = visible_columns.map { |column| csv_safe(raw_cell_value(record, column)) }
            y << CSV.generate_line(row)
          end
          break if batch.size < EXPORT_BATCH_SIZE
          offset += EXPORT_BATCH_SIZE
        end
      end
    end

    private

    def load_table_class
      @table_class = Infotable::TableResolver.resolve(params[:table_name])
    rescue Infotable::TableResolver::NotFound => e
      render plain: e.message, status: :not_found
    end

    def authorize_table
      head :forbidden unless @table_class.authorized?(self)
    end

    def set_params
      @page = params[:page].to_s.to_i.clamp(1, MAX_PAGE)
      @per_page = sanitize_per_page(scalar_param(:per_page))
      @sorts = parse_sorts
      @sort_column = @sorts.first&.first
      @sort_direction = @sorts.first ? @sorts.first.last : normalize_sort_direction(scalar_param(:sort_direction))
      @filters = params[:filters].respond_to?(:to_unsafe_h) ? params[:filters] : {}
      @search = scalar_param(:search).to_s.strip.presence
      @infinite_scroll_enabled = @table_class.infinite_scroll_enabled?
    end

    def process_table_request
      @query = build_query

      # Apply pagination
      @pagy, @records = paginate(@page)
    rescue Pagy::RangeError # page past the end: show the first page
      @page_out_of_range = true
      @pagy, @records = paginate(1)
    end

    def paginate(page)
      if @table_class.countless?
        pagy(:countless, @query, limit: @per_page, page: page, raise_range_error: true)
      else
        pagy(:offset, @query, limit: @per_page, page: page, raise_range_error: true)
      end
    end

    # Base query + filters + sorting, shared by show/data and export
    def build_query
      query = @table_class.base_query(self)

      if @filters.present?
        query = Infotable::FilterProcessor.new(query, @table_class, @filters).apply
      end

      if @search
        query = Infotable::SearchProcessor.new(query, @table_class, @search).apply
      end

      query = apply_sorting(query)
      @table_class.preloads.any? ? query.preload(*@table_class.preloads) : query
    end

    def apply_sorting(query)
      sorts = @sorts.presence || default_sorts
      return query if sorts.empty?

      query = sorts.reduce(query) do |relation, (column, direction)|
        relation.order(Arel.sql("#{get_sort_expression(column, relation)} #{direction}"))
      end
      add_sort_tiebreaker(query, sorts.map(&:first))
    end

    def default_sorts
      column = @table_class.sort_settings[:column]
      return [] unless column

      [ [ column.to_s, normalize_sort_direction(@table_class.sort_settings[:direction]) ] ]
    end

    MAX_SORTS = 3

    # Multi-column: sort=name:asc,age:desc (shift-click in the UI). Falls back to the
    # single sort_column / sort_direction pair. Unknown or non-sortable columns are dropped.
    def parse_sorts
      pairs =
        if (multi = scalar_param(:sort)).present?
          multi.split(",").first(MAX_SORTS).map { |item| item.split(":", 2) }
        elsif (single = scalar_param(:sort_column)).present?
          [ [ single, scalar_param(:sort_direction) ] ]
        else
          []
        end

      pairs.filter_map do |name, direction|
        [ name.to_s, normalize_sort_direction(direction) ] if column_sortable?(name)
      end.uniq(&:first)
    end

    # Equal sort keys have no defined order in PostgreSQL, so rows can repeat or vanish
    # between pages. Order by the primary key last to make pagination stable.
    def add_sort_tiebreaker(query, sort_columns)
      model = query.model
      pk = model.primary_key
      return query if pk.blank? || sort_columns.map(&:to_s).include?(pk) || query.distinct_value || query.group_values.any?

      query.order(Arel.sql("#{model.table_name}.#{pk} ASC"))
    end

    MAX_PER_PAGE = 500
    MAX_PAGE = 1_000_000

    # Query params are user input: arrays/hashes ("sort_column[]=x") are treated as absent
    def scalar_param(key)
      value = params[key]
      value.is_a?(String) ? value : nil
    end
    EXPORT_BATCH_SIZE = 1000

    def sanitize_per_page(value)
      default = @table_class.pagination_settings[:per_page]
      requested = value.to_i
      requested.positive? ? [ requested, MAX_PER_PAGE ].min : default
    end

    PLAIN_NUMBER = /\A[+-]?\d+([.,]\d+)?\z/

    # Guard against spreadsheet formula injection. Plain numbers ("-5", "+48123456789") are
    # not formulas and are left alone.
    def csv_safe(value)
      return value unless value.is_a?(String) && value.match?(/\A[=+\-@\t\r]/)
      return value if value.match?(PLAIN_NUMBER)

      "'#{value}"
    end

    def render_table_frame
      respond_to do |format|
        format.html { render "infotable/tables/show" }
        format.turbo_stream {
          # For turbo-stream requests, render the show template
          # Turbo will extract the frame content
          render "infotable/tables/show"
        }
      end
    end

    # Normalize sort direction to always be a string ('asc' or 'desc')
    def normalize_sort_direction(direction)
      direction = direction.to_s.downcase
      %w[asc desc].include?(direction) ? direction : "asc"
    end

    # Check if column is sortable
    def column_sortable?(column_name)
      @table_class.sortable_columns.any? { |col| col[:name].to_s == column_name.to_s }
    end

    # Sanitize column name to prevent SQL injection
    def sanitize_column_name(column_name)
      # Only allow alphanumeric characters, underscores, and dots (for associations)
      column_name.to_s.gsub(/[^a-zA-Z0-9_.]/, "")
    end

    # Get the SQL expression for sorting a column
    # For virtual columns, use virtual_sql if provided, otherwise use qualified column name
    def get_sort_expression(column_name, query)
      column = @table_class.columns.find { |col| col[:name].to_s == column_name.to_s }

      if column && column[:sort_sql].present?
        column[:sort_sql]
      elsif column && column[:sql].present?
        column[:sql]
      elsif column && column[:virtual] && column[:virtual_sql].present?
        # Virtual column with SQL expression - use it directly
        column[:virtual_sql]
      else
        # Regular column - qualify with table name to avoid ambiguous column errors
        table_name = query.model.table_name
        sanitized_column = sanitize_column_name(column_name)
        "#{table_name}.#{sanitized_column}"
      end
    end

    # Extract raw cell value for CSV export (without formatting)
    def raw_cell_value(record, column)
      value = @table_class.cell_value(record, column)

      # Return nil placeholder if value is nil
      if value.nil?
        return @table_class.nil_value_placeholder
      end

      # Return empty placeholder if value is empty string
      if value.is_a?(String) && value.empty?
        return @table_class.empty_value_placeholder
      end

      # Return raw value without formatting
      case column[:type]
      when :datetime, :date
        value.iso8601
      when :boolean
        value ? "true" : "false"
      else
        value.is_a?(Array) ? value.join(", ") : value.to_s
      end
    end
  end
end
