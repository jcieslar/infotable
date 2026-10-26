begin
  require "mcp"
rescue LoadError
  abort "infotable-mcp needs the mcp gem: add `gem \"mcp\", group: :development` to your Gemfile and run bundle install"
end

require "json"
require "rails/generators"
require "tmpdir"

module Infotable
  # MCP server for creating tables with an AI assistant. See exe/infotable-mcp.
  module Mcp
    autoload :Introspection, "infotable/mcp/introspection"
    autoload :Server, "infotable/mcp/server"
    autoload :TableWriter, "infotable/mcp/table_writer"
    autoload :TableChecker, "infotable/mcp/table_checker"

    def self.text(payload)
      text = payload.is_a?(String) ? payload : JSON.pretty_generate(payload)
      ::MCP::Tool::Response.new([ { type: "text", text: text } ])
    end

    def self.error(message)
      ::MCP::Tool::Response.new([ { type: "text", text: message } ], error: true)
    end
  end
end

require "infotable/mcp/tools"
