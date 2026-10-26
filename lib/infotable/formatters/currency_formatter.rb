module Infotable
  module Formatters
    # formatter: :currency
    #   formatter_options: { unit: "$", precision: 2, delimiter: ",", separator: "." }
    # Options you leave out come from I18n (`number.currency.format`) for the current locale.
    class CurrencyFormatter < BaseFormatter
      def format(value, record, options = {})
        return "" if value.blank?

        number_to_currency(value, options.slice(:unit, :precision, :delimiter, :separator))
      end
    end
  end
end
