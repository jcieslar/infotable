module Infotable
  module Mcp
    # Loads a table and looks for mistakes before the app does: columns the model lacks,
    # a default sort on a missing column, a query that raises. Optionally returns a few rows.
    class TableChecker
      def initialize(name: nil, source: nil, preview: 0)
        @name = name
        @source = source
        @preview = preview.to_i.clamp(0, 20)
      end

      def call
        table = load_table
        problems = []
        model = nil

        begin
          model = table.base_query.model
        rescue StandardError => e
          return { ok: false, problems: [ "query raises #{e.class}: #{e.message}" ] }
        end

        problems.concat(column_problems(table, model))
        problems.concat(sort_problems(table))
        problems << "no authorize block: anyone who can reach the engine routes can read this table" if table.table_authorize.nil?

        rows = preview_rows(table, problems)
        { ok: problems.none? { !_1.start_with?("no authorize") }, table: table.name, model: model.name, problems: problems, preview: rows }.compact
      end

      private

      def load_table
        if @source
          mod = Module.new
          mod.module_eval(@source.sub(/class \S+ </, "class CheckedTable <"), "infotable_mcp_check.rb")
          mod.const_get(:CheckedTable)
        else
          reload_app
          Infotable::TableResolver.resolve(@name)
        end
      end

      # A table written a moment ago is not known to the autoloader yet
      def reload_app
        Rails.application.reloader.reload! if Rails.application.config.enable_reloading
      rescue StandardError
        nil
      end

      def column_problems(table, model)
        table.columns.filter_map do |col|
          next if col[:value] || col[:virtual] || col[:sql] || %i[action actions].include?(col[:type])
          next if model.column_names.include?(col[:name].to_s) || model.method_defined?(col[:name])

          "column :#{col[:name]} is not an attribute of #{model.name}: add value:, sql: or virtual:"
        end
      end

      def sort_problems(table)
        column = table.sort_settings[:column]
        return [] if column.nil? || table.columns.any? { _1[:name].to_s == column.to_s }

        [ "default_sort :#{column} is not a defined column" ]
      end

      def preview_rows(table, problems)
        return nil if @preview.zero?

        columns = table.visible_columns.reject { %i[action actions].include?(_1[:type]) }
        table.base_query.limit(@preview).map do |record|
          columns.to_h { |col| [ col[:name], table.cell_value(record, col).to_s ] }
        end
      rescue StandardError => e
        problems << "query raises #{e.class}: #{e.message}"
        nil
      end
    end
  end
end
