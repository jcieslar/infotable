module Infotable
  module Formatters
    # formatter: :filesize
    # Bytes as a human size: 1536 => "1.5 KB". `formatter_options: { precision: 2 }` (significant digits)
    class FilesizeFormatter < BaseFormatter
      def format(value, record, options = {})
        return "" if value.nil? || value == ""
        return value.to_s if Float(value.to_s, exception: false).nil?

        view_context.number_to_human_size(value, precision: options.fetch(:precision, 2), strip_insignificant_zeros: true)
      end
    end
  end
end
