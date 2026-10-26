module Infotable
  module Mcp
    class ListModels < ::MCP::Tool
      tool_name "list_models"
      description "Models of this Rails app with column types, enums and associations. Call first, so column names are not guessed."
      input_schema(properties: {})
      annotations(read_only_hint: true)

      def self.call(server_context: nil)
        Mcp.text(Introspection.models)
      end
    end

    class ListTables < ::MCP::Tool
      tool_name "list_tables"
      description "InfoTable tables that already exist in app/infotable, with their columns and settings. Use them as the house style."
      input_schema(properties: {})
      annotations(read_only_hint: true)

      def self.call(server_context: nil)
        Mcp.text(Introspection.tables)
      end
    end

    class DescribeDsl < ::MCP::Tool
      tool_name "describe_dsl"
      description "The table DSL of the installed infotable version: column options, types, filters, formatters, settings. The full guide is the infotable://readme resource."
      input_schema(properties: {})
      annotations(read_only_hint: true)

      def self.call(server_context: nil)
        Mcp.text(Introspection.dsl)
      end
    end

    class TableOptions < ::MCP::Tool
      tool_name "table_options"
      description "Settings of a new table for a model, as questions with defaults proposed from the model. " \
                  "Ask the user these (all at once, defaults pre-filled) before calling generate_table."
      input_schema(properties: { model: { type: "string", description: "Model class name, e.g. Order or Admin::Invoice" } }, required: [ "model" ])
      annotations(read_only_hint: true)

      def self.call(model:, server_context: nil)
        Mcp.text(Introspection.table_options(model) || "#{model} is not an ActiveRecord model; call list_models")
      end
    end

    class GenerateTable < ::MCP::Tool
      tool_name "generate_table"
      description "Generates app/infotable/<models>_table.rb for a model with the infotable:table generator. " \
                  "Shows the code only; set write: true to save it (refuses to replace a file unless overwrite: true). " \
                  "Answers from table_options map to the parameters. Run validate_table afterwards."
      input_schema(
        properties: {
          model: { type: "string" },
          only: { type: "array", items: { type: "string" }, description: "Only these columns" },
          skip: { type: "array", items: { type: "string" }, description: "Leave these columns out" },
          per_page: { type: "integer" },
          sort: { type: "string", description: "column:direction, e.g. created_at:desc" },
          toolbar: { type: "string", enum: %w[header rail] },
          row_click: { type: "boolean" },
          infinite_scroll: { type: "boolean" },
          countless: { type: "boolean" },
          checkbox: { type: "boolean" },
          associations: { type: "boolean", description: "belongs_to associations as columns through left_joins (default true)" },
          formatters: { type: "boolean", description: "Currency/percent/link/boolean formatters picked from column names (default true)" },
          title: { type: "string" },
          subtitle: { type: "string" },
          authorize: { type: "string", description: "Ruby expression over `controller`, e.g. controller.current_user&.admin?" },
          write: { type: "boolean", description: "Save the file (default: only show the code)" },
          overwrite: { type: "boolean" }
        },
        required: [ "model" ]
      )

      def self.call(model:, write: false, overwrite: false, server_context: nil, **settings)
        writer = TableWriter.new(model, settings)
        result = write ? writer.write(overwrite: overwrite) : writer.render
        Mcp.text(path: result.path, written: write, code: result.code)
      rescue TableWriter::Error => e
        Mcp.error(e.message)
      end
    end

    class ValidateTable < ::MCP::Tool
      tool_name "validate_table"
      description "Loads a table (by name like posts_table, or from source code) and reports mistakes: missing columns, bad default sort, " \
                  "failing query. preview: N also returns the first N rows as the table would show them."
      input_schema(
        properties: {
          name: { type: "string", description: "Table name, e.g. orders_table or admin_orders_table" },
          source: { type: "string", description: "Table source code to check without saving it" },
          preview: { type: "integer", description: "Rows to return (max 20)" }
        }
      )
      annotations(read_only_hint: true)

      def self.call(name: nil, source: nil, preview: 0, server_context: nil)
        return Mcp.error("pass name or source") if name.blank? && source.blank?

        Mcp.text(TableChecker.new(name: name, source: source, preview: preview).call)
      rescue Infotable::TableResolver::NotFound, ScriptError, StandardError => e
        Mcp.error("#{e.class}: #{e.message}")
      end
    end

    # Shared by the tools that edit an existing table file
    module EditsTable
      TABLE = { type: "string", description: "Table name, e.g. orders_table (see list_tables)" }.freeze
      WRITE = { type: "boolean", description: "Save the change (default: only return the diff)" }.freeze

      def edit_table(name, write)
        result = yield TableEditor.new(name, write: write)
        Mcp.text(path: result.path, written: result.written, diff: result.diff, problems: result.problems)
      rescue TableEditor::Error, Infotable::TableResolver::NotFound, ArgumentError => e
        Mcp.error(e.message)
      end
    end

    COLUMN_OPTIONS_HELP = "Column options as {name: value}: type, label, sortable, searchable, filterable, filter_type, visible, pinned (left/right), " \
                          "width, sql, sort_sql, includes, formatter (currency, percent, link, badge, boolean... or a lambda as Ruby source), " \
                          "formatter_options, value and filter_options (Ruby source), see describe_dsl. Booleans and integers stay JSON."

    class AddColumn < ::MCP::Tool
      extend EditsTable
      tool_name "add_column"
      description "Adds a column to an existing table (after the last column, or after `after`). Returns the diff; write: true saves it. " \
                  "Refuses edits that leave the file unparsable or break the table."
      input_schema(
        properties: {
          table: EditsTable::TABLE, name: { type: "string" }, after: { type: "string", description: "Place it after this column" },
          options: { type: "object", description: COLUMN_OPTIONS_HELP }, write: EditsTable::WRITE
        },
        required: %w[table name]
      )

      def self.call(table:, name:, options: {}, after: nil, write: false, server_context: nil)
        edit_table(table, write) { _1.add_column(name, options, after: after) }
      end
    end

    class UpdateColumn < ::MCP::Tool
      extend EditsTable
      tool_name "update_column"
      description "Changes options of an existing column (or adds the ones it lacks), e.g. make it filterable with a select filter or pinned. " \
                  "Other options, comments and layout are left alone."
      input_schema(
        properties: { table: EditsTable::TABLE, name: { type: "string" }, options: { type: "object", description: COLUMN_OPTIONS_HELP }, write: EditsTable::WRITE },
        required: %w[table name options]
      )

      def self.call(table:, name:, options:, write: false, server_context: nil)
        edit_table(table, write) { _1.update_column(name, options) }
      end
    end

    class RemoveColumn < ::MCP::Tool
      extend EditsTable
      tool_name "remove_column"
      description "Removes a column from an existing table"
      input_schema(properties: { table: EditsTable::TABLE, name: { type: "string" }, write: EditsTable::WRITE }, required: %w[table name])

      def self.call(table:, name:, write: false, server_context: nil)
        edit_table(table, write) { _1.remove_column(name) }
      end
    end

    class AddBatchAction < ::MCP::Tool
      extend EditsTable
      tool_name "add_batch_action"
      description "Adds a bulk action to the table's batch_actions block (creating the block, which also turns the checkbox column on). " \
                  "The app has to implement the endpoint at url; it receives ids[]."
      input_schema(
        properties: {
          table: EditsTable::TABLE, name: { type: "string" }, url: { type: "string" }, label: { type: "string" },
          method: { type: "string", enum: Infotable::BatchActions::METHODS.map(&:to_s) },
          confirm: { type: "string", description: "Confirmation text; %{count} is the number of rows" },
          color: { type: "string", enum: Infotable::BatchActions::COLORS.map(&:to_s) }, write: EditsTable::WRITE
        },
        required: %w[table name url]
      )

      def self.call(table:, name:, url:, label: nil, method: nil, confirm: nil, color: nil, write: false, server_context: nil)
        edit_table(table, write) do |editor|
          editor.add_batch_action(name, **{ url: url, label: label, method: method, confirm: confirm, color: color }.compact)
        end
      end
    end

    class SetOption < ::MCP::Tool
      extend EditsTable
      tool_name "set_option"
      description "Sets or replaces a table setting: #{TableEditor::SETTINGS.keys.join(', ')}. args is the Ruby source of its arguments " \
                  "(per_page: 50, default_sort: :created_at, :desc, authorize: a boolean expression over `controller`)."
      input_schema(
        properties: {
          table: EditsTable::TABLE, setting: { type: "string", enum: TableEditor::SETTINGS.keys },
          args: { type: "string", description: "Examples: " + TableEditor::SETTINGS.map { |k, v| "#{k} #{v}".strip }.first(6).join("; ") }, write: EditsTable::WRITE
        },
        required: %w[table setting]
      )

      def self.call(table:, setting:, args: nil, write: false, server_context: nil)
        edit_table(table, write) { _1.set_option(setting, args) }
      end
    end

    class NewTablePrompt < ::MCP::Prompt
      prompt_name "new_table"
      description "Create an InfoTable table for a model, asking the user about its settings first"
      arguments [ ::MCP::Prompt::Argument.new(name: "model", description: "Model class name", required: true) ]

      def self.template(args, server_context: nil)
        model = args["model"] || args[:model]
        text = <<~TEXT
          Create an InfoTable table for #{model}.
          1. Call list_tables to see how tables in this app look, and table_options for #{model}.
          2. Ask the user the questions of table_options in ONE message, with the proposed defaults filled in, and wait for the answers.
          3. Call generate_table with the answers (without write) and show the code.
          4. After the user agrees, call generate_table with write: true, then validate_table with preview: 5 and report the result.
          generate_table adds belongs_to association columns and picks formatters (currency, percent, link, boolean) by itself:
          tell the user which ones it chose from the code and offer associations: false / formatters: false if they do not want that.
          Add a batch action or a custom formatter only when the user asks; describe_dsl lists what exists.
        TEXT
        ::MCP::Prompt::Result.new(messages: [ ::MCP::Prompt::Message.new(role: "user", content: ::MCP::Content::Text.new(text)) ])
      end
    end
  end
end
