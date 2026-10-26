require "generators/infotable/table/table_generator"

module Infotable
  module Mcp
    # Renders a table with the `infotable:table` generator into a scratch directory,
    # so the code can be shown first and written to app/infotable only on request.
    class TableWriter
      Result = Struct.new(:path, :code, keyword_init: true)

      class Error < StandardError; end

      FLAGS = %i[only skip per_page sort toolbar row_click infinite_scroll countless checkbox authorize
                 associations formatters title subtitle].freeze

      def initialize(model, settings = {})
        @model = model.to_s
        @settings = settings.to_h.symbolize_keys.slice(*FLAGS).compact
      end

      def render
        raise Error, "unknown model #{@model}" unless @model.safe_constantize.is_a?(Class)

        Dir.mktmpdir("infotable-mcp") do |dir|
          shell = Thor::Base.shell.new
          generator = Infotable::Generators::TableGenerator.new([ @model ], switches, destination_root: dir, shell: shell)
          shell.mute { generator.invoke_all }

          file = Dir.glob("app/infotable/**/*.rb", base: dir).first or raise Error, "the generator wrote nothing"
          code = File.read(File.join(dir, file))
          check_syntax!(code)
          Result.new(path: file, code: code)
        end
      end

      # Writes the rendered table into the app; an existing file is only replaced with overwrite: true
      def write(overwrite: false)
        result = render
        target = Rails.root.join(result.path)
        raise Error, "#{result.path} already exists, pass overwrite: true to replace it" if target.exist? && !overwrite

        target.dirname.mkpath
        target.write(result.code)
        result
      end

      private

      def switches
        @settings.flat_map do |key, value|
          flag = "--#{key.to_s.dasherize}"
          case value
          when true then [ flag ]
          when false then [ "--no-#{key.to_s.dasherize}" ]
          when Array then [ flag, *value.map(&:to_s) ]
          else [ flag, value.to_s ]
          end
        end
      end

      def check_syntax!(code)
        RubyVM::InstructionSequence.compile(code)
      rescue SyntaxError => e
        raise Error, "generated code does not parse (check authorize/sort values): #{e.message.lines.first&.strip}"
      end
    end
  end
end
