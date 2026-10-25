module Infotable
  module Formatters
    # formatter: :link
    #   formatter_options: {
    #     url: ->(record) { user_path(record) },   # Proc (run in the view), Symbol (helper method) or String
    #     label: ->(record) { record.email },      # optional, defaults to the cell value
    #     external: true,                          # target=_blank rel="noopener noreferrer"
    #     class: "..."                             # replaces the default classes
    #   }
    # Without url: the value itself is the URL (handy for website columns); mailto:/tel: work too.
    class LinkFormatter < BaseFormatter
      ALLOWED_SCHEMES = %w[http https mailto tel].freeze
      DEFAULT_CLASSES = "text-indigo-600 dark:text-indigo-400 hover:text-indigo-800 dark:hover:text-indigo-200 hover:underline".freeze

      def format(value, record, options = {})
        label = resolve(options[:label], record) || value
        return "" if label.blank? && value.blank?

        url = options.key?(:url) ? resolve(options[:url], record) : value
        return label.to_s unless self.class.safe_url?(url)

        attributes = { href: url.to_s, class: options[:class] || DEFAULT_CLASSES }
        attributes.merge!(target: "_blank", rel: "noopener noreferrer") if options[:external]

        link_to(label.to_s, url.to_s, attributes)
      end

      # Relative URLs, http(s), mailto and tel. Everything else (javascript:, data:, ...) is rendered as text.
      def self.safe_url?(url)
        return false if url.blank?

        cleaned = url.to_s.gsub(/[[:cntrl:][:space:]]/, "")
        scheme = cleaned[/\A([a-z][a-z0-9+.\-]*):/i, 1]
        scheme.nil? || ALLOWED_SCHEMES.include?(scheme.downcase)
      end

      private

      def resolve(option, record)
        case option
        when Proc then view_context.instance_exec(record, &option)
        when Symbol then view_context.send(option, record)
        else option
        end
      end
    end
  end
end
