module Infotable
  module Formatters
    class ActionFormatter < BaseFormatter
      def format(value, record, options = {})
        actions = options[:actions] || []
        style = options[:style] || :buttons # :buttons, :links, :dropdown

        case style
        when :buttons
          render_buttons(actions, record)
        when :dropdown
          render_dropdown(actions, record)
        else
          render_links(actions, record)
        end
      end

      private

      def render_buttons(actions, record)
        buttons = actions.map do |action|
          render_button(action, record)
        end

        safe_join(buttons, " ")
      end

      def render_links(actions, record)
        links = actions.map do |action|
          render_link(action, record)
        end

        safe_join(links, " • ")
      end

      def render_button(action, record)
        url = resolve_url(action[:url], record)
        method = action[:method] || :get
        data = action[:data] || {}

        link_to(
          button_content(action),
          url,
          class: button_classes(action[:color]),
          data: link_data(data, method, action[:confirm])
        )
      end

      def render_link(action, record)
        url = resolve_url(action[:url], record)
        method = action[:method] || :get
        data = action[:data] || {}

        link_to(
          action[:label] || action[:icon] || view_context.t("infotable.formatters.action"),
          url,
          class: link_classes(action[:color]),
          data: link_data(data, method, action[:confirm])
        )
      end

      # Turbo-compatible: non-GET verbs use data-turbo-method, confirm uses data-turbo-confirm
      def link_data(data, method, confirm)
        data = data.dup
        data[:turbo_method] = method unless method.to_sym == :get
        data[:turbo_confirm] = confirm if confirm
        data
      end

      def render_menu_item(action, record)
        link_to(
          action[:label] || action[:icon] || view_context.t("infotable.formatters.action"),
          resolve_url(action[:url], record),
          role: "menuitem",
          class: "block px-3 py-1.5 text-sm whitespace-nowrap #{link_classes(action[:color])} hover:bg-gray-50 dark:hover:bg-gray-800",
          data: link_data(action[:data] || {}, action[:method] || :get, action[:confirm])
        )
      end

      def render_dropdown(actions, record)
        # <details> gives open/close and keyboard support without JS
        content_tag(:details, class: "relative inline-block text-left") do
          summary = content_tag(:summary, "\u22EF".html_safe,
            class: "list-none cursor-pointer inline-flex items-center px-2 py-1 rounded-md border border-gray-300 dark:border-gray-600 bg-white dark:bg-gray-900 text-gray-600 dark:text-gray-400 hover:bg-gray-50 dark:hover:bg-gray-800",
            "aria-label": view_context.t("infotable.formatters.action"), "aria-haspopup": "menu")
          menu = content_tag(:div, role: "menu",
            class: "absolute right-0 z-30 mt-1 min-w-36 rounded-md border border-gray-200 dark:border-gray-700 bg-white dark:bg-gray-900 py-1 shadow-lg") do
            safe_join(actions.map { |action| render_menu_item(action, record) })
          end
          summary + menu
        end
      end

      def button_content(action)
        if action[:icon]
          safe_join([ html_safe(action[:icon]), (action[:label] ? " #{action[:label]}" : nil) ].compact)
        else
          action[:label] || view_context.t("infotable.formatters.action")
        end
      end

      def button_classes(color = nil)
        base = "inline-flex items-center px-2 py-1 border text-xs font-medium rounded-md transition-colors"

        color_classes = case color&.to_s
        when "primary"
          "border-indigo-600 bg-indigo-600 text-white hover:bg-indigo-700"
        when "danger"
          "border-red-600 bg-red-600 text-white hover:bg-red-700"
        when "success"
          "border-green-600 bg-green-600 text-white hover:bg-green-700"
        else
          "border-gray-300 dark:border-gray-600 bg-white dark:bg-gray-900 text-gray-700 dark:text-gray-300 hover:bg-gray-50 dark:hover:bg-gray-800"
        end

        "#{base} #{color_classes}"
      end

      def link_classes(color = nil)
        case color&.to_s
        when "danger"
          "text-red-600 dark:text-red-400 hover:text-red-900 dark:hover:text-red-300"
        when "success"
          "text-green-600 dark:text-green-400 hover:text-green-900 dark:hover:text-green-300"
        else
          "text-indigo-600 dark:text-indigo-400 hover:text-indigo-900 dark:hover:text-indigo-200"
        end
      end

      def resolve_url(url, record)
        if url.is_a?(Proc)
          view_context.instance_exec(record, &url)
        elsif url.is_a?(Symbol)
          view_context.send(url, record)
        else
          url
        end
      end
    end
  end
end
