module Infotable
  module Formatters
    # formatter: :number
    #   formatter_options: {
    #     precision: 2,       # decimals; without it the number is shown as it is
    #     delimiter: ",",     # thousands separator, default ","
    #     separator: ".",     # decimal separator, default "."
    #     unit: "ms",         # appended after the number
    #     compact: true,      # 1.2k, 3.4M, 5B (precision defaults to 1)
    #     zero: "-"           # shown instead of 0
    #   }
    class NumberFormatter < BaseFormatter
      COMPACT_STEPS = [ [ 1_000_000_000, "B" ], [ 1_000_000, "M" ], [ 1_000, "k" ] ].freeze

      def format(value, record, options = {})
        return "" if value.nil? || value == ""

        number = Float(value.to_s, exception: false)
        return value.to_s if number.nil?
        return options[:zero].to_s if options.key?(:zero) && number.zero?

        text = options[:compact] ? compact(value, number, options) : plain(value, options)
        text = "#{text} #{options[:unit]}" if options[:unit].present?
        content_tag(:span, text, class: "tabular-nums")
      end

      private

      def plain(value, options)
        delimiter = options.fetch(:delimiter, ",")
        separator = options.fetch(:separator, ".")
        return view_context.number_with_delimiter(value, delimiter: delimiter, separator: separator) unless options[:precision]

        view_context.number_with_precision(value, precision: options[:precision], delimiter: delimiter, separator: separator)
      end

      def compact(value, number, options)
        divisor, suffix = COMPACT_STEPS.find { |step, _| number.abs >= step }
        return plain(value, options) unless divisor

        view_context.number_with_precision(number / divisor, precision: options.fetch(:precision, 1),
                                           separator: options.fetch(:separator, "."), strip_insignificant_zeros: true) + suffix
      end
    end
  end
end
