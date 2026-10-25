module Infotable
  module Formatters
    class BadgeFormatter < BaseFormatter
      # Default color mappings
      DEFAULT_COLORS = {
        active: "green",
        inactive: "gray",
        pending: "yellow",
        success: "green",
        warning: "yellow",
        error: "red",
        info: "blue",
        primary: "indigo"
      }.freeze

      def format(value, record, options = {})
        return "" if value.blank?

        color = determine_color(value, options)
        size = options[:size] || :medium
        display_value = options[:label] || value.to_s.titleize

        render_badge(display_value, color, size)
      end

      private

      def determine_color(value, options)
        # Check if custom color mapping provided
        if options[:colors].is_a?(Hash)
          return options[:colors][value.to_s.downcase.to_sym] || options[:colors][value.to_s] || "gray"
        end

        # Use default mapping
        DEFAULT_COLORS[value.to_s.downcase.to_sym] || "gray"
      end

      def render_badge(text, color, size)
        classes = badge_classes(color, size)
        content_tag(:span, text, class: classes)
      end

      def badge_classes(color, size)
        base = "inline-flex items-center rounded-full font-medium"

        size_classes = case size
        when :small
          "px-2 py-0.5 text-xs"
        when :large
          "px-3 py-1 text-sm"
        else # medium
          "px-2.5 py-0.5 text-xs"
        end

        color_classes = case color.to_s
        when "green"
          "bg-green-100 dark:bg-green-900/40 text-green-800 dark:text-green-300"
        when "red"
          "bg-red-100 dark:bg-red-900/40 text-red-800 dark:text-red-300"
        when "yellow"
          "bg-yellow-100 dark:bg-yellow-900/40 text-yellow-800 dark:text-yellow-300"
        when "blue"
          "bg-blue-100 dark:bg-blue-900/40 text-blue-800 dark:text-blue-300"
        when "indigo"
          "bg-indigo-100 dark:bg-indigo-900/40 text-indigo-800 dark:text-indigo-300"
        when "purple"
          "bg-purple-100 dark:bg-purple-900/40 text-purple-800 dark:text-purple-300"
        when "pink"
          "bg-pink-100 dark:bg-pink-900/40 text-pink-800 dark:text-pink-300"
        when "cyan"
          "bg-cyan-100 dark:bg-cyan-900/40 text-cyan-800 dark:text-cyan-300"
        else # gray
          "bg-gray-100 dark:bg-gray-800 text-gray-800 dark:text-gray-200"
        end

        "#{base} #{size_classes} #{color_classes}"
      end
    end
  end
end
