require "prism"
require "open3"

module Infotable
  module Mcp
    # Small, exact edits of an existing table file: the file is parsed with Prism to find the statement
    # to touch, so formatting, comments and lambdas around it stay as they are. The edited source must
    # parse and must not introduce problems TableChecker finds; only then it can be written.
    class TableEditor
      Result = Struct.new(:path, :written, :diff, :problems, keyword_init: true)

      class Error < StandardError; end

      NAME = /\A[a-z_][a-z0-9_]*\z/

      SYMBOL_OPTIONS = %i[type filter_type pinned].freeze
      STRING_OPTIONS = %i[label width sql sort_sql virtual_sql].freeze
      BOOLEAN_OPTIONS = %i[sortable searchable filterable visible exportable virtual filter_multi_select].freeze
      INTEGER_OPTIONS = %i[filter_options_limit].freeze
      # Everything else (value, formatter_options, filter_options, actions, ...) is Ruby source

      # Table settings set_option can write: name => example of its arguments
      SETTINGS = {
        "per_page" => "25", "per_page_options" => "[10, 25, 50]", "default_sort" => ":created_at, :desc",
        "toolbar" => ":rail", "infinite_scroll" => "true", "countless" => "true", "url_state" => "false",
        "resizable_columns" => "true", "row_click" => "", "row_size" => ":slim", "table_title" => '"Orders"',
        "table_subtitle" => '"All orders"', "table_height" => ":fill", "nil_value" => '"-"', "empty_value" => '"(empty)"',
        "checkbox_column" => "", "authorize" => "controller.current_user&.admin?"
      }.freeze

      attr_reader :path

      # write: false only computes the edit and shows the diff
      def initialize(table_name, write: false)
        @write = write
        @klass = Infotable::TableResolver.resolve(table_name)
        @path = source_path
        @source = File.read(@path)
      end

      def add_column(name, options = {}, after: nil)
        name = column_name(name)
        raise Error, "column :#{name} already exists, use update_column" if find_column(name)

        statement = column_statement(name, options)
        anchor = after ? (find_column(column_name(after)) or raise Error, missing_column(after)) : columns.last
        edit { insert_after(anchor, statement, anchor ? indent_of(anchor) : "  ", blank_line: true) }
      end

      # Changes the given options of a column, adding the ones it does not have yet
      def update_column(name, options)
        node = find_column(column_name(name)) or raise Error, missing_column(name)
        raise Error, "no options given" if options.blank?

        options = check_options(options)
        edit { update_options(node, options) }
      end

      def remove_column(name)
        node = find_column(column_name(name)) or raise Error, missing_column(name)

        edit { remove_lines(node) }
      end

      def add_batch_action(name, **action)
        Infotable::BatchActions::Builder.new.action(name, **action) # same checks as the DSL
        statement = "action :#{name}, " + action.compact.map { |key, value| "#{key}: #{%i[method color].include?(key) ? ":#{value}" : literal(value)}" }.join(", ")
        block = batch_actions_block

        edit do
          if block
            body = block.block.body&.body&.last
            if body
              insert_after(body, statement, indent_of(body))
            else
              insert_lines_after(block.block.opening_loc.start_line, [ "#{indent_of(block)}  #{statement}" ])
            end
          else
            append_to_class([ "batch_actions do", "  #{statement}", "end" ])
          end
        end
      rescue ArgumentError => e
        raise Error, e.message
      end

      def set_option(setting, args = nil)
        setting = setting.to_s
        raise Error, "unknown setting #{setting}, use one of #{SETTINGS.keys.join(', ')}" unless SETTINGS.key?(setting)

        statement = setting == "authorize" ? "authorize { |controller| #{args} }" : [ setting, args.presence ].compact.join(" ")
        edit do
          node = class_statements.find { _1.is_a?(Prism::CallNode) && _1.receiver.nil? && _1.name.to_s == setting }
          node ? replace_lines(node, statement) : append_to_class([ statement ])
        end
      end

      private

      # Runs the block (it returns the new source) and checks the outcome; the file is only written when write is true
      def edit(&block)
        finish(instance_exec(&block))
      end

      def finish(new_source)
        problems = syntax_problems(new_source)
        raise Error, "the edit leaves the file unparsable: #{problems.first}" if problems.any?

        added = check(new_source) - check(@source)
        raise Error, "the edit would introduce: #{added.join('; ')}" if added.any?

        File.write(@path, new_source) if @write
        Result.new(path: relative_path, written: @write ? true : false, diff: diff(new_source), problems: check(new_source))
      end

      def check(source)
        report = Infotable::Mcp::TableChecker.new(source: source).call
        report[:problems].reject { _1.start_with?("no authorize") }
      rescue StandardError, ScriptError => e
        [ "loading the table raises #{e.class}: #{e.message.lines.first&.strip}" ]
      end

      def syntax_problems(source)
        Prism.parse(source).errors.map { "line #{_1.location.start_line}: #{_1.message}" }
      end

      def source_path
        file = Object.const_source_location(@klass.name)&.first
        root = Rails.root.join("app/infotable").to_s
        raise Error, "cannot find the file of #{@klass.name}" unless file && File.exist?(file)
        raise Error, "#{file} is outside app/infotable, edit it by hand" unless File.expand_path(file).start_with?("#{root}/")

        file
      end

      def relative_path
        Pathname.new(@path).relative_path_from(Rails.root).to_s
      end

      # --- finding things -------------------------------------------------

      def parsed
        Prism.parse(@source)
      end

      def class_node
        @class_node ||= begin
          found = nil
          walk = lambda do |node|
            next unless node.respond_to?(:compact_child_nodes)
            found ||= node if node.is_a?(Prism::ClassNode) && node.constant_path.slice.end_with?(@klass.name.demodulize)
            node.compact_child_nodes.each(&walk)
          end
          walk.call(parsed.value)
          found or raise Error, "cannot find class #{@klass.name} in #{relative_path}"
        end
      end

      def class_statements
        class_node.body&.body || []
      end

      def columns
        class_statements.select { _1.is_a?(Prism::CallNode) && _1.receiver.nil? && _1.name == :column }
      end

      def find_column(name)
        columns.find { |node| node.arguments&.arguments&.first.then { _1.is_a?(Prism::SymbolNode) && _1.unescaped == name.to_s } }
      end

      def batch_actions_block
        class_statements.find { _1.is_a?(Prism::CallNode) && _1.receiver.nil? && _1.name == :batch_actions && _1.block.is_a?(Prism::BlockNode) }
      end

      def missing_column(name)
        "no column :#{name}; the table has #{columns.filter_map { _1.arguments.arguments.first.try(:unescaped) }.join(', ')}"
      end

      # --- editing the text -----------------------------------------------

      def lines
        @source.lines
      end

      def indent_of(node)
        " " * node.location.start_column
      end

      def insert_after(node, statement, indent, blank_line: false)
        return append_to_class(statement.lines.map(&:chomp)) unless node

        new_lines = statement.lines.map { "#{indent}#{_1.chomp}" }
        new_lines.unshift("") if blank_line
        insert_lines_after(node.location.end_line, new_lines)
      end

      def insert_lines_after(line_number, new_lines)
        all = lines
        all.insert(line_number, *new_lines.map { "#{_1}\n" })
        all.join
      end

      def append_to_class(statement_lines)
        close = class_node.end_keyword_loc.start_line
        all = lines
        before = all[close - 2].to_s
        block = statement_lines.map { _1.empty? ? "\n" : "  #{_1}\n" }
        block.unshift("\n") unless before.strip.empty?
        all.insert(close - 1, *block)
        all.join
      end

      def replace_lines(node, statement)
        all = lines
        all[(node.location.start_line - 1)..(node.location.end_line - 1)] = [ "#{indent_of(node)}#{statement}\n" ]
        all.join
      end

      def remove_lines(node)
        all = lines
        from = node.location.start_line - 1
        to = node.location.end_line - 1
        all.slice!(from..to)
        all.delete_at(from) if from.positive? && all[from - 1].to_s.strip.empty? && all[from].to_s.strip.empty?
        all.join
      end

      def update_options(node, options)
        args = node.arguments.arguments
        hash = args.find { _1.is_a?(Prism::KeywordHashNode) }
        existing = hash ? hash.elements.select { _1.is_a?(Prism::AssocNode) && _1.key.is_a?(Prism::SymbolNode) } : []
        edits = [] # [byte offset, bytes to replace, text]
        additions = []

        options.each do |key, value|
          current = existing.find { _1.key.unescaped == key.to_s }
          if current
            edits << [ current.value.location.start_offset, current.value.location.length, render(key, value) ]
          else
            additions << "#{key}: #{render(key, value)}"
          end
        end

        if additions.any?
          last = (existing.last || args.last)
          multiline = hash && hash.location.start_line != hash.location.end_line
          separator = multiline ? ",\n#{' ' * hash.elements.first.location.start_column}" : ", "
          edits << [ last.location.end_offset, 0, (hash ? "" : ", ") + (hash ? separator : "") + additions.join(separator) ]
        end

        result = @source.dup
        edits.sort_by(&:first).reverse_each { |offset, length, text| result.bytesplice(offset, length, text) }
        result
      end

      def diff(new_source)
        Dir.mktmpdir do |dir|
          old_file = File.join(dir, "before.rb")
          new_file = File.join(dir, "after.rb")
          File.write(old_file, @source)
          File.write(new_file, new_source)
          output, = Open3.capture2("diff", "-u", "--label", "a/#{relative_path}", "--label", "b/#{relative_path}", old_file, new_file)
          output
        end
      rescue SystemCallError
        new_source
      end

      # --- rendering Ruby -------------------------------------------------

      def column_name(name)
        name = name.to_s
        raise Error, "#{name.inspect} is not a valid column name" unless name.match?(NAME)

        name
      end

      def check_options(options)
        options = options.to_h.symbolize_keys
        unknown = options.keys - Infotable::Base::COLUMN_OPTIONS
        raise Error, "unknown column option(s) #{unknown.join(', ')}; use #{Infotable::Base::COLUMN_OPTIONS.join(', ')}" if unknown.any?

        options
      end

      def column_statement(name, options)
        options = check_options(options)
        parts = options.map { |key, value| "#{key}: #{render(key, value)}" }
        ([ "column :#{name}#{',' if parts.any?}" ] + parts.each_with_index.map { |part, i| "  #{part}#{',' if i < parts.size - 1}" }).join("\n")
      end

      def render(key, value)
        key = key.to_sym
        if SYMBOL_OPTIONS.include?(key) || (key == :formatter && value.to_s.match?(/\A\w+\z/))
          ":#{value}"
        elsif STRING_OPTIONS.include?(key)
          value.to_s.inspect
        elsif BOOLEAN_OPTIONS.include?(key)
          [ true, "true" ].include?(value) ? "true" : "false"
        elsif INTEGER_OPTIONS.include?(key)
          Integer(value).to_s
        elsif key == :includes && value.to_s.match?(/\A\w+\z/)
          ":#{value}"
        else
          value.to_s
        end
      rescue ArgumentError, TypeError
        raise Error, "#{key}: #{value.inspect} is not valid"
      end

      def literal(value)
        case value
        when Symbol then ":#{value}"
        when String then value.inspect
        else value.inspect
        end
      end
    end
  end
end
