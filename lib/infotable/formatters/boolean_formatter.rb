module Infotable
  module Formatters
    class BooleanFormatter < BaseFormatter
      def format(value, record, options = {})
        true_text = options[:true_text] || view_context.t("infotable.formatters.boolean.true")
        false_text = options[:false_text] || view_context.t("infotable.formatters.boolean.false")
        style = options[:style] || :badge # :badge, :text, :icon

        case style
        when :badge
          format_as_badge(value, true_text, false_text)
        when :icon
          format_as_icon(value, true_text, false_text)
        else
          value ? true_text : false_text
        end
      end

      private

      def format_as_badge(value, true_text, false_text)
        if value
          content_tag(:span, true_text, class: "inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-green-100 dark:bg-green-900/40 text-green-800 dark:text-green-300")
        else
          content_tag(:span, false_text, class: "inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-gray-100 dark:bg-gray-800 text-gray-800 dark:text-gray-200")
        end
      end

      def format_as_icon(value, true_text, false_text)
        if value
          html_safe('<svg class="w-5 h-5 text-green-500" fill="currentColor" viewBox="0 0 20 20" role="img" aria-label="' + ERB::Util.html_escape(true_text) + '"><path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.707-9.293a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z" clip-rule="evenodd"/></svg>')
        else
          html_safe('<svg class="w-5 h-5 text-gray-400" fill="currentColor" viewBox="0 0 20 20" role="img" aria-label="' + ERB::Util.html_escape(false_text) + '"><path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zM8.707 7.293a1 1 0 00-1.414 1.414L8.586 10l-1.293 1.293a1 1 0 101.414 1.414L10 11.414l1.293 1.293a1 1 0 001.414-1.414L11.414 10l1.293-1.293a1 1 0 00-1.414-1.414L10 8.586 8.707 7.293z" clip-rule="evenodd"/></svg>')
        end
      end
    end
  end
end
