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
          Add a batch action, formatter or association column only when the user asks; describe_dsl lists what exists.
        TEXT
        ::MCP::Prompt::Result.new(messages: [ ::MCP::Prompt::Message.new(role: "user", content: ::MCP::Content::Text.new(text)) ])
      end
    end
  end
end
