module Infotable
  module Generators
    # rails generate infotable:table User
    # rails generate infotable:table Admin::Order --only=id,number,status --skip=notes
    class TableGenerator < Rails::Generators::NamedBase
      source_root File.expand_path("templates", __dir__)

      desc "Create an InfoTable definition in app/infotable from a model's columns"

      class_option :only, type: :array, default: [], desc: "Only these columns"
      class_option :skip, type: :array, default: [], desc: "Leave these columns out"

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
            primary_key: name == @model.primary_key.to_s
          }
        end
      end

      # belongs_to associations become commented hints: they need a join the app has to choose
      def association_hints
        return [] unless @model.respond_to?(:reflect_on_all_associations)

        @model.reflect_on_all_associations(:belongs_to).map(&:name)
      end

      def default_sort_line
        names = column_specs.map { _1[:name] }
        if names.include?("created_at")
          "default_sort :created_at, :desc"
        elsif names.any?
          "default_sort :#{names.first}, :asc"
        end
      end
    end
  end
end
