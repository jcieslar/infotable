module Infotable
  module Formatters
    # formatter: :tags (alias :list)
    # The value is an Array, a relation or a comma separated string; every item becomes a small badge.
    #   formatter_options: {
    #     limit: 3,                        # show this many, then "+N" (the rest is in its tooltip)
    #     label: ->(item) { item.name },   # text of an item, defaults to item.to_s
    #     colors: { "admin" => "red" },    # item => badge colour, as in :badge (default gray)
    #     separator: ", "                  # plain text joined with this instead of badges
    #   }
    class TagsFormatter < BaseFormatter
      def format(value, record, options = {})
        labels = items(value).map { label_for(_1, options) }.reject(&:blank?)
        return "" if labels.empty?

        return safe_join(labels, options[:separator].to_s) if options[:separator]

        limit = options[:limit]
        shown, rest = limit ? [ labels.first(limit), labels.drop(limit) ] : [ labels, [] ]
        badges = shown.map { badge(_1, options) }
        badges << content_tag(:span, "+#{rest.size}", title: rest.join(", "), class: "text-xs text-gray-500 dark:text-gray-400") if rest.any?
        content_tag(:div, safe_join(badges), class: "flex flex-wrap items-center gap-1")
      end

      private

      def items(value)
        return [] if value.nil?
        return value.split(",").map(&:strip) if value.is_a?(String)

        value.respond_to?(:to_a) ? value.to_a : [ value ]
      end

      def label_for(item, options)
        label = options[:label].is_a?(Proc) ? view_context.instance_exec(item, &options[:label]) : item
        label.to_s
      end

      def badge(text, options)
        BadgeFormatter.new(view_context).format(text, nil, label: text, size: :small, colors: options[:colors])
      end
    end
  end
end
