module Infotable
  module Formatters
    # formatter: :duration
    # Seconds as "1h 05m" (:short, default) or "1 hour 5 minutes" (:long).
    #   formatter_options: { format: :short, parts: 2 }   # parts: how many units to show, from the largest
    class DurationFormatter < BaseFormatter
      UNITS = { d: 86_400, h: 3600, m: 60, s: 1 }.freeze

      def format(value, record, options = {})
        return "" if value.nil? || value == ""

        seconds = Float(value.to_s, exception: false)
        return value.to_s if seconds.nil? || seconds.negative?

        parts = split(seconds.round).first(options.fetch(:parts, 2))
        parts = [ [ :s, 0 ] ] if parts.empty?
        options[:format].to_s == "long" ? long(parts) : short(parts)
      end

      private

      # [[:h, 1], [:m, 5]]; units with nothing in them are left out
      def split(seconds)
        UNITS.filter_map do |unit, size|
          count, seconds = seconds.divmod(size)
          [ unit, count ] if count.positive?
        end
      end

      def short(parts)
        parts.each_with_index.map do |(unit, count), index|
          number = index.zero? ? count.to_s : count.to_s.rjust(2, "0")
          view_context.t("infotable.formatters.duration.short.#{unit}", count: number)
        end.join(" ")
      end

      def long(parts)
        parts.map { |unit, count| view_context.t("infotable.formatters.duration.long.#{unit}", count: count) }.join(" ")
      end
    end
  end
end
