module Infotable
  module Formatters
    # formatter: :truncate
    # Long text cut to `length` characters; the full text stays in the cell's tooltip.
    #   formatter_options: { length: 60, omission: "…" }
    class TruncateFormatter < BaseFormatter
      def format(value, record, options = {})
        return "" if value.blank?

        text = value.to_s
        length = options.fetch(:length, 60)
        return text if text.length <= length

        shortened = view_context.truncate(text, length: length, omission: options.fetch(:omission, "…"))
        content_tag(:span, shortened, title: text)
      end
    end
  end
end
