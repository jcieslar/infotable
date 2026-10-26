module Infotable
  module Formatters
    class DateFormatter < BaseFormatter
      def format(value, record, options = {})
        return "" if value.blank?

        value = parse_value(value)
        return value.to_s if value.is_a?(String)

        format = options[:format] || :default

        case format
        when :short, :long, :time, :datetime
          view_context.l(value, format: view_context.t("infotable.formatters.date.#{format}"))
        when :relative
          time_ago_in_words(value)
        when :dot_date
          value.strftime("%d.%m.%Y")
        when :default
          # Use Rails default
          value.strftime("%Y-%m-%d %H:%M")
        else
          # Custom format string
          if format.is_a?(String)
            value.strftime(format)
          else
            # Try to use I18n localization
            begin
              view_context.l(value, format: format)
            rescue
              value.strftime("%Y-%m-%d %H:%M")
            end
          end
        end
      end

      private

      def parse_value(value)
        return value unless value.is_a?(String)

        Time.zone.parse(value) || value
      rescue ArgumentError
        value
      end

      def time_ago_in_words(value)
        view_context.t("infotable.formatters.ago", time: view_context.time_ago_in_words(value))
      end
    end
  end
end
