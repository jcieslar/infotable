module Infotable
  module Formatters
    class CurrencyFormatter < BaseFormatter
      def format(value, record, options = {})
        return "" if value.blank?

        unit = options[:unit] || "$"
        precision = options[:precision] || 2
        delimiter = options[:delimiter] || ","
        separator = options[:separator] || "."

        number_to_currency(
          value,
          unit: unit,
          precision: precision,
          delimiter: delimiter,
          separator: separator
        )
      end
    end
  end
end
