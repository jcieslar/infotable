require "generators/infotable/table/table_generator"

module Infotable
  module Mcp
    # What the host app looks like: models and their columns, tables that exist, the DSL of this gem version.
    module Introspection
      module_function

      def models
        Rails.application.eager_load!
        ActiveRecord::Base.descendants.reject { _1.abstract_class? || _1.name.nil? || !_1.table_exists? }.sort_by(&:name).map { describe_model(_1) }
      end

      def describe_model(model)
        {
          name: model.name,
          table: model.table_name,
          columns: model.columns.to_h { [ _1.name, _1.type.to_s ] },
          enums: model.defined_enums.transform_values(&:keys),
          associations: model.reflect_on_all_associations.map { { name: _1.name, kind: _1.macro, model: _1.options[:class_name] || _1.name.to_s.classify } }
        }
      end

      def tables
        Rails.application.eager_load!
        Infotable::Base.descendants.reject { _1.name.nil? }.sort_by(&:name).map { describe_table(_1) }
      end

      def describe_table(table)
        {
          class: table.name,
          model: (table.base_query.model.name rescue nil),
          columns: table.columns.map { |col| col.slice(:name, :type, :sortable, :searchable, :filterable, :filter_type, :visible, :pinned).compact },
          per_page: table.pagination_settings[:per_page],
          default_sort: table.sort_settings.presence,
          toolbar: table.toolbar_mode,
          batch_actions: table.batch_action_list.map { _1[:name] },
          row_click: table.row_click?,
          infinite_scroll: table.infinite_scroll_enabled?,
          countless: table.countless?,
          no_authorize_block: table.table_authorize.nil?
        }
      end

      # The DSL as this gem version knows it, read from the code so it cannot drift from the docs
      def dsl
        {
          version: Infotable::VERSION,
          column_options: Infotable::Base::COLUMN_OPTIONS,
          column_types: Infotable::Generators::TableGenerator::TYPE_MAP.values.map { _1[:type] }.uniq + %i[badge currency percent link avatar action],
          filter_types: %i[text boolean number date select],
          formatters: Infotable::Formatters.constants.map { _1.to_s.delete_suffix("Formatter").underscore }.reject { _1 == "base" },
          toolbar_modes: %i[header rail],
          table_settings: %i[query query_sql per_page per_page_options default_sort infinite_scroll countless url_state resizable_columns
                             toolbar row_click row_link row_class row_data row_size checkbox_column batch_actions authorize export_columns
                             table_title table_subtitle table_height nil_value empty_value],
          batch_action_options: { required: %i[url], optional: %i[label method confirm color], methods: Infotable::BatchActions::METHODS, colors: Infotable::BatchActions::COLORS },
          generate_table_options: Infotable::Generators::TableGenerator.class_options.keys
        }
      end

      # Questions to put to the user before generating a table, each with a default proposed from the model
      def table_options(model_name)
        model = model_name.to_s.safe_constantize
        return nil unless model.is_a?(Class) && model < ActiveRecord::Base

        columns = model.column_names.reject { Infotable::Generators::TableGenerator::SENSITIVE.match?(_1) }
        enums = model.defined_enums.keys
        sort = columns.include?("created_at") ? "created_at:desc" : "#{model.primary_key}:asc"
        belongs_to = model.reflect_on_all_associations(:belongs_to).map(&:name)

        {
          model: model.name,
          notes: [
            ("enum columns (#{enums.join(', ')}) become badges with a select filter" if enums.any?),
            ("belongs_to #{belongs_to.join(', ')}: generated as a commented hint, a column needs a join" if belongs_to.any?),
            "foreign keys and sensitive columns (password, token...) are left out"
          ].compact,
          questions: [
            { param: "only", ask: "Which columns?", choices: columns, default: "all of the choices" },
            { param: "sort", ask: "Default sort (column:direction)?", choices: columns, default: sort },
            { param: "per_page", ask: "Rows per page?", choices: [ 10, 25, 50, 100 ], default: 25 },
            { param: "toolbar", ask: "Toolbar: header bar or slim rail?", choices: %w[header rail], default: "header" },
            { param: "checkbox", ask: "Row selection column?", default: false },
            { param: "row_click", ask: "Clicking a row opens it (needs row_link)?", default: false },
            { param: "infinite_scroll", ask: "Infinite scroll instead of pages?", default: false },
            { param: "countless", ask: "Skip the total count (tables over ~1M rows)?", default: false },
            { param: "authorize", ask: "Who may see the table? A Ruby expression over `controller`", default: "controller.current_user.present?" }
          ]
        }
      end
    end
  end
end
