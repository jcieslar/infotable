module Infotable
  class FilterProcessor
    attr_reader :query, :table_class, :filters

    def initialize(query, table_class, filters = {})
      @query = query
      @table_class = table_class
      @filters = normalize_filters(filters)
      @table_name = query.model.table_name
    end

    # Apply all filters to the query
    def apply
      return query if filters.blank?

      filters.each do |column_name, filter_params|
        next if filter_params.blank?

        column = find_column(column_name)
        next unless column && column[:filterable]

        @query = apply_filter(column, filter_params)
      end

      query
    end

    private

    # Accept Hash / ActionController::Parameters, drop anything else
    def normalize_filters(filters)
      filters = filters.to_unsafe_h if filters.respond_to?(:to_unsafe_h)
      filters.is_a?(Hash) ? filters.with_indifferent_access : {}
    end

    # Scalar-only string value (arrays/hashes from tampered params become nil)
    def scalar(value)
      return nil if value.is_a?(Array) || value.is_a?(Hash)

      value.is_a?(String) ? value.delete("\u0000") : value # PostgreSQL rejects NUL bytes
    end

    # Aggregate (virtual_sql) columns filter with HAVING; row-level :sql columns with WHERE
    def having?(column)
      column[:virtual] && column[:sql].blank?
    end

    def find_column(column_name)
      table_class.columns.find { |col| col[:name].to_s == column_name.to_s }
    end

    # Get qualified column reference for SQL queries
    # Returns either the virtual SQL expression or the qualified table.column format
    def qualified_column_ref(column)
      if column[:sql].present?
        column[:sql]
      elsif column[:virtual] && column[:virtual_sql].present?
        column[:virtual_sql]
      else
        "#{@table_name}.#{column[:name]}"
      end
    end

    def apply_filter(column, filter_params)
      filter_type = determine_filter_type(column)

      case filter_type
      when :text
        apply_text_filter(column, filter_params)
      when :boolean
        apply_boolean_filter(column, filter_params)
      when :number
        apply_number_filter(column, filter_params)
      when :date
        apply_date_filter(column, filter_params)
      when :select
        apply_select_filter(column, filter_params)
      else
        query
      end
    end

    def determine_filter_type(column)
      # Explicit filter_type
      return column[:filter_type].to_sym if column[:filter_type]

      # Infer from column type
      case column[:type]
      when :string, :text
        :text
      when :boolean
        :boolean
      when :integer, :float, :decimal, :number
        :number
      when :date, :datetime
        :date
      when :select
        :select
      else
        :text
      end
    end

    # Text filter with operations
    def apply_text_filter(column, params)
      return query unless params.is_a?(Hash)

      op = params[:op] || params["op"] || "contains"
      value = scalar(params[:value] || params["value"])
      column_name = column[:name]
      is_virtual = having?(column)
      # Use qualified column reference
      column_ref = qualified_column_ref(column)

      result = query

      # Use having() for virtual columns, where() for regular columns
      filter_method = is_virtual ? :having : :where

      case op
      when "contains"
        result = result.public_send(filter_method, "#{column_ref} ILIKE ?", "%#{sanitize_like(value)}%") if value.present?
      when "exact"
        if is_virtual
          result = result.having("LOWER(#{column_ref}) = LOWER(?)", value) if value.present?
        else
          result = result.where("LOWER(#{column_ref}) = LOWER(?)", value) if value.present?
        end
      when "not_contain"
        result = result.public_send(filter_method, "NOT #{column_ref} ILIKE ?", "%#{sanitize_like(value)}%") if value.present?
      when "starts_with"
        result = result.public_send(filter_method, "#{column_ref} ILIKE ?", "#{sanitize_like(value)}%") if value.present?
      when "ends_with"
        result = result.public_send(filter_method, "#{column_ref} ILIKE ?", "%#{sanitize_like(value)}") if value.present?
      when "is_empty"
        result = result.public_send(filter_method, "#{column_ref} IS NULL OR #{column_ref} = ''")
      when "is_not_empty"
        if is_virtual
          result = result.having("#{column_ref} IS NOT NULL AND #{column_ref} != ''")
        else
          result = result.where.not("#{column_ref} IS NULL OR #{column_ref} = ''")
        end
      end

      result
    end

    # Boolean filter
    def apply_boolean_filter(column, params)
      return query unless params.is_a?(Hash)

      value = scalar(params[:value] || params["value"])
      column_name = column[:name]
      is_virtual = having?(column)
      # Use qualified column reference
      column_ref = qualified_column_ref(column)

      result = query

      # Use having() for virtual columns, where() for regular columns
      filter_method = is_virtual ? :having : :where

      case value.to_s
      when "true"
        if is_virtual
          result = result.having("#{column_ref} = ?", true)
        else
          result = result.where("#{column_ref} = ?", true)
        end
      when "false"
        if is_virtual
          result = result.having("#{column_ref} = ?", false)
        else
          result = result.where("#{column_ref} = ?", false)
        end
      when "is_empty"
        if is_virtual
          result = result.having("#{column_ref} IS NULL")
        else
          result = result.where("#{column_ref} IS NULL")
        end
      when "is_not_empty"
        if is_virtual
          result = result.having("#{column_ref} IS NOT NULL")
        else
          result = result.where.not("#{column_ref} IS NULL")
        end
      end

      result
    end

    NUMBER_OPERATORS = { "eq" => "=", "neq" => "<>", "gt" => ">", "gte" => ">=", "lt" => "<", "lte" => "<=" }.freeze

    # Number filter. Without :op it is a range (from/to, either may be blank).
    # With :op (eq neq gt gte lt lte between is_empty is_not_empty) it compares :value.
    def apply_number_filter(column, params)
      return query unless params.is_a?(Hash)

      column_ref = qualified_column_ref(column)
      filter_method = having?(column) ? :having : :where
      op = (params[:op] || params["op"]).to_s

      case op
      when "is_empty"     then return query.public_send(filter_method, "#{column_ref} IS NULL")
      when "is_not_empty" then return query.public_send(filter_method, "#{column_ref} IS NOT NULL")
      when *NUMBER_OPERATORS.keys
        value = numeric(scalar(params[:value] || params["value"]))
        return value.nil? ? query : query.public_send(filter_method, "#{column_ref} #{NUMBER_OPERATORS[op]} CAST(? AS numeric)", value)
      end

      from = numeric(scalar(params[:from] || params["from"]))
      to = numeric(scalar(params[:to] || params["to"]))
      result = query
      # CAST: a decimal bound against an integer column is otherwise rejected by PostgreSQL
      result = result.public_send(filter_method, "#{column_ref} >= CAST(? AS numeric)", from) if from
      result = result.public_send(filter_method, "#{column_ref} <= CAST(? AS numeric)", to) if to
      result
    end

    # Date filter. Without :op it is a range (from/to). With :op (on before after between
    # is_empty is_not_empty) it compares :value; `on` matches the whole day.
    def apply_date_filter(column, params)
      return query unless params.is_a?(Hash)

      column_ref = qualified_column_ref(column)
      filter_method = having?(column) ? :having : :where
      datetime = column[:type] == :datetime
      op = (params[:op] || params["op"]).to_s

      case op
      when "is_empty"     then return query.public_send(filter_method, "#{column_ref} IS NULL")
      when "is_not_empty" then return query.public_send(filter_method, "#{column_ref} IS NOT NULL")
      when "on", "before", "after"
        day = parse_date(scalar(params[:value] || params["value"]))
        return query unless day

        return case op
               when "on"     then query.public_send(filter_method, "#{column_ref} >= ? AND #{column_ref} <= ?", datetime ? day.beginning_of_day : day, datetime ? day.end_of_day : day)
               when "before" then query.public_send(filter_method, "#{column_ref} < ?", datetime ? day.beginning_of_day : day)
               else               query.public_send(filter_method, "#{column_ref} > ?", datetime ? day.end_of_day : day)
               end
      end

      from = parse_date(scalar(params[:from] || params["from"]))
      to = parse_date(scalar(params[:to] || params["to"]))
      to = to.end_of_day if to && datetime

      result = query
      result = result.public_send(filter_method, "#{column_ref} >= ?", from) if from
      result = result.public_send(filter_method, "#{column_ref} <= ?", to) if to
      result
    end

    # Select filter: one value (params[:value]) or several (array, or params[:value] as array).
    # Values are cast to the column type; values the type cannot hold never match.
    def apply_select_filter(column, params)
      raw = params.is_a?(Hash) ? (params[:value] || params["value"]) : params
      values = Array(raw).flatten.reject { |v| v.is_a?(Hash) || v.blank? }.map { |v| v.to_s.delete("\u0000") }.reject(&:blank?)
      return query if values.empty?

      typed = values.map { |v| cast_select_value(column, v) }.reject(&:nil?)
      return query.none if typed.empty?

      ref = qualified_column_ref(column)
      # Custom SQL of unknown type (declared :string but e.g. comments.author_id): compare as text
      ref = "CAST(#{ref} AS text)" if (column[:sql].present? || column[:virtual]) && DECLARED_TYPES[column[:type]].nil?

      query.public_send(having?(column) ? :having : :where, "#{ref} IN (?)", typed)
    end

    INTEGER_RANGE = (-(2**63)..(2**63 - 1))

    def cast_select_value(column, value)
      case select_column_type(column)
      when :integer, :bigint
        Integer(value, 10, exception: false)&.then { |n| n if INTEGER_RANGE.cover?(n) }
      when :decimal, :float
        numeric(value)
      when :boolean
        { "true" => true, "false" => false, "1" => true, "0" => false }[value.downcase]
      when :date, :datetime
        parse_date(value)
      else
        value
      end
    end

    DECLARED_TYPES = { integer: :integer, number: :decimal, decimal: :decimal, float: :decimal, currency: :decimal,
                       boolean: :boolean, date: :date, datetime: :datetime }.freeze

    # Attribute type of the model column; for custom SQL / aggregate columns the type declared in the DSL
    def select_column_type(column)
      unless column[:sql].present? || column[:virtual]
        db_type = query.model.columns_hash[column[:name].to_s]&.type
        return db_type if db_type
      end

      DECLARED_TYPES[column[:type]]
    end

    # Helper to sanitize LIKE values
    def sanitize_like(value)
      return "" if value.blank?
      value.to_s.gsub(/[%_]/, '\\\\\&')
    end

    def numeric(value)
      number = BigDecimal(value.to_s)
      return nil unless number.finite?

      number.frac.zero? ? number.to_i : number
    rescue ArgumentError, TypeError
      nil
    end

    # Helper to parse date strings
    def parse_date(date_string)
      return nil if date_string.blank?

      Date.parse(date_string.to_s)
    rescue ArgumentError, RangeError
      nil
    end
  end
end
