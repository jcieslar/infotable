module Infotable
  module Mcp
    module Server
      TOOLS = [ ListModels, ListTables, DescribeDsl, TableOptions, GenerateTable, ValidateTable, AddColumn, UpdateColumn, RemoveColumn, AddBatchAction, SetOption ].freeze

      module_function

      def build
        readme = ::MCP::Resource.new(uri: "infotable://readme", name: "infotable-readme", title: "InfoTable README",
                                     description: "Full documentation of the table DSL", mime_type: "text/markdown")
        server = ::MCP::Server.new(
          name: "infotable", version: Infotable::VERSION, tools: TOOLS, prompts: [ NewTablePrompt ], resources: [ readme ],
          instructions: "Creates InfoTable tables in this Rails app. Start with list_models and table_options; ask the user for the settings before generate_table. To change an existing table use add_column, update_column, remove_column, add_batch_action or set_option (they return a diff; write: true saves)."
        )
        server.resources_read_handler do |params|
          [ { uri: params[:uri], mimeType: "text/markdown", text: File.read(Infotable.root.join("README.md")) } ]
        end
        server
      end

      def run
        ::MCP::Server::Transports::StdioTransport.new(build).open
      end
    end
  end
end
