module Infotable
  # Global search: every whitespace-separated term must match (ILIKE) at least one
  # searchable column. Non-text columns are matched on their text representation.
  class SearchProcessor
    MAX_TERMS = 5
    MAX_TERM_LENGTH = 100

    attr_reader :query, :table_class, :term

    def initialize(query, table_class, term)
      @query = query
      @table_class = table_class
      @term = term.to_s.delete("\u0000") # PostgreSQL rejects NUL bytes
    end

    def apply
      columns = searchable_columns
      return query if columns.empty?

      terms.reduce(query) do |relation, word|
        pattern = "%#{ActiveRecord::Base.sanitize_sql_like(word)}%"
        conditions = columns.map { "CAST(#{column_ref(_1)} AS text) ILIKE :pattern" }
        relation.where(conditions.join(" OR "), pattern: pattern)
      end
    end

    private

    def terms
      term.split.first(MAX_TERMS).map { _1.first(MAX_TERM_LENGTH) }
    end

    # Aggregate (HAVING) columns can't be searched with WHERE
    def searchable_columns
      table_class.searchable_columns.reject { |col| col[:virtual] && col[:sql].blank? }
    end

    def column_ref(column)
      column[:sql].presence || "#{query.model.table_name}.#{column[:name]}"
    end
  end
end
