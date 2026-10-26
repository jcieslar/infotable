module Infotable
  module Generators
    # rails generate infotable:table User
    # rails generate infotable:table Admin::Order --only=id,number,status --skip=notes
    class TableGenerator < Rails::Generators::NamedBase
      source_root File.expand_path("templates", __dir__)

      desc "Create an InfoTable definition in app/infotable from a model's columns"

      class_option :only, type: :array, default: [], desc: "Only these columns"
      class_option :skip, type: :array, default: [], desc: "Leave these columns out"
      class_option :per_page, type: :numeric, default: 25, desc: "Rows per page"
      class_option :sort, type: :string, desc: "Default sort as column:direction, e.g. created_at:desc"
      class_option :toolbar, type: :string, desc: "Toolbar mode: header or rail"
      class_option :row_click, type: :boolean, default: false, desc: "Clicking a row opens its row_link"
      class_option :infinite_scroll, type: :boolean, default: false, desc: "Infinite scroll instead of pages"
      class_option :countless, type: :boolean, default: false, desc: "Skip the total count (big tables)"
      class_option :checkbox, type: :boolean, default: false, desc: "Row selection column"
      class_option :associations, type: :boolean, default: true, desc: "Show belongs_to associations as columns (left_joins) instead of commented hints"
      class_option :formatters, type: :boolean, default: true, desc: "Pick currency/percent/link/boolean formatters from column names and types"
      class_option :title, type: :string, desc: "Table title"
      class_option :subtitle, type: :string, desc: "Table subtitle"
      class_option :authorize, type: :string, desc: "Ruby expression over `controller` that decides who sees the table"

      # Attribute of an associated record that names it, first match wins
      DISPLAY_ATTRIBUTES = %w[name title label email].freeze

      CURRENCY_NAME = /(price|amount|total|cost|salary|fee|revenue|balance)\z/
      PERCENT_NAME = /(percent|percentage|rate)\z/
      URL_NAME = /(_url|website)\z/

      # Attributes that must never end up in a table by accident
      SENSITIVE = /password|digest|token|secret|otp|encrypted/

      TYPE_MAP = {
        string: { type: :string, filter: :text },
        text: { type: :text, filter: :text },
        integer: { type: :integer, filter: :number },
        bigint: { type: :integer, filter: :number },
        float: { type: :float, filter: :number },
        decimal: { type: :decimal, filter: :number },
        boolean: { type: :boolean, filter: :boolean },
        date: { type: :date, filter: :date },
        datetime: { type: :datetime, filter: :date },
        timestamp: { type: :datetime, filter: :date },
        time: { type: :string, filter: :text }
      }.freeze

      def create_table_file
        @model = model_class
        say_status :warning, "#{class_name} not found; generating an empty table to fill in", :yellow unless @model

        template "table.rb.tt", File.join("app/infotable", class_path, "#{table_file_name}.rb")
      end

      private

      def table_file_name
        "#{file_name.pluralize}_table"
      end

      def table_class_name
        (class_path.map(&:camelize) + [ "#{file_name.pluralize.camelize}Table" ]).join("::")
      end

      def model_class
        class_name.safe_constantize
      end

      # Column definitions as hashes: name, type, filter, searchable, select options
      def column_specs
        return [] unless @model.respond_to?(:columns)

        foreign_keys = @model.respond_to?(:reflect_on_all_associations) ? @model.reflect_on_all_associations(:belongs_to).map { _1.foreign_key.to_s } : []

        @model.columns.filter_map do |column|
          name = column.name
          next if SENSITIVE.match?(name)
          next if foreign_keys.include?(name)
          next if options[:only].any? && options[:only].exclude?(name)
          next if options[:skip].include?(name)

          spec = TYPE_MAP[column.type] || { type: :string, filter: :text }
          enum_values = @model.respond_to?(:defined_enums) ? @model.defined_enums[name]&.keys : nil

          {
            name: name,
            type: enum_values ? :badge : spec[:type],
            filter: enum_values ? :select : spec[:filter],
            enum_values: enum_values,
            searchable: %i[string text].include?(column.type) && enum_values.nil?,
            primary_key: name == @model.primary_key.to_s,
            formatter_lines: enum_values ? [] : formatter_lines(column)
          }
        end
      end

      # Formatter for a column, picked from its type and name (--no-formatters turns this off)
      def formatter_lines(column)
        return [] unless options[:formatters]

        name = column.name
        case column.type
        when :boolean
          [ "formatter: :boolean" ]
        when :decimal, :float
          if name.match?(CURRENCY_NAME)
            [ "formatter: :currency", "formatter_options: { precision: 2 }" ]
          elsif name.match?(PERCENT_NAME)
            [ "formatter: :percent", "formatter_options: { precision: 1 }" ]
          else
            []
          end
        when :string
          if name == "email"
            [ "formatter: :link", %(formatter_options: { url: ->(record) { "mailto:\#{record.email}" } }) ]
          elsif name.match?(URL_NAME)
            [ "formatter: :link", "formatter_options: { external: true }" ]
          else
            []
          end
        else
          []
        end
      end

      # belongs_to associations shown as columns: they sort, search and filter on the associated record's
      # display attribute through a left join. One association per table and only when the associated
      # model has an attribute to show; the rest become commented hints.
      def association_specs
        @association_specs ||= @model.respond_to?(:table_name) ? build_association_specs : []
      end

      def build_association_specs
        taken = [ @model.table_name ]
        candidate_associations.filter_map do |reflection|
          klass = reflection.klass rescue nil
          display = klass && DISPLAY_ATTRIBUTES.find { klass.column_names.include?(_1) }
          next unless display && taken.exclude?(klass.table_name)

          taken << klass.table_name
          { name: reflection.name, table: klass.table_name, display: display }
        end
      end

      # The rest: unfit for a join column, so a hint the app has to finish
      def association_hints
        belongs_to_reflections.map(&:name) - association_specs.map { _1[:name] }
      end

      def candidate_associations
        options[:associations] ? belongs_to_reflections : []
      end

      # The belongs_to associations --only / --skip leave in; polymorphic ones have no single table to join
      def belongs_to_reflections
        return [] unless @model.respond_to?(:reflect_on_all_associations)

        @model.reflect_on_all_associations(:belongs_to).reject do |reflection|
          reflection.polymorphic? ||
            (options[:only].any? && options[:only].exclude?(reflection.name.to_s)) || options[:skip].include?(reflection.name.to_s)
        end
      end

      def query_expression
        return "#{class_name}.all" if association_specs.empty?

        "#{class_name}.left_joins(#{association_specs.map { ":#{_1[:name]}" }.join(', ')})"
      end

      # Table-level settings chosen with the options above, one DSL line each
      def setting_lines
        lines = []
        lines << "table_title #{options[:title].inspect}" if options[:title].present?
        lines << "table_subtitle #{options[:subtitle].inspect}" if options[:subtitle].present?
        lines << "toolbar :#{options[:toolbar]}" if options[:toolbar].present?
        lines << "infinite_scroll true" if options[:infinite_scroll]
        lines << "countless" if options[:countless]
        lines << "checkbox_column" if options[:checkbox]
        lines << "row_click" if options[:row_click]
        lines
      end

      def default_sort_line
        names = column_specs.map { _1[:name] }
        if options[:sort].present?
          column, direction = options[:sort].split(":")
          "default_sort :#{column}, :#{direction == 'desc' ? 'desc' : 'asc'}"
        elsif names.include?("created_at")
          "default_sort :created_at, :desc"
        elsif names.any?
          "default_sort :#{names.first}, :asc"
        end
      end
    end
  end
end
