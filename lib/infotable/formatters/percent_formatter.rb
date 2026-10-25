module Infotable
  module Formatters
    # formatter: :percent
    #   formatter_options: {
    #     precision: 1,       # decimals, default 0
    #     scale: :percent,    # :percent (value is 0-100, default) or :ratio (value is 0-1)
    #     bar: true           # small progress bar next to the number
    #   }
    class PercentFormatter < BaseFormatter
      def format(value, record, options = {})
        return "" if value.nil? || value == ""

        number = Float(value.to_s, exception: false)
        return value.to_s if number.nil?

        number *= 100 if options[:scale].to_s == "ratio"
        text = view_context.number_to_percentage(number, precision: options.fetch(:precision, 0), strip_insignificant_zeros: false)
        return text unless options[:bar]

        width = number.clamp(0, 100).round
        bar = content_tag(:div, content_tag(:div, "", class: "h-full rounded-full bg-indigo-500", style: "width: #{width}%"),
                          class: "h-1.5 w-16 rounded-full bg-gray-200 dark:bg-gray-700 flex-none", role: "presentation")
        content_tag(:div, safe_join([ content_tag(:span, text, class: "tabular-nums"), bar ]), class: "flex items-center gap-2")
      end
    end
  end
end
