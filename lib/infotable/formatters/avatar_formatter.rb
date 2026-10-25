module Infotable
  module Formatters
    # formatter: :avatar
    # The cell value is the image URL. With no image, initials of `name` are shown on a coloured disc.
    #   formatter_options: {
    #     name: ->(record) { record.name },   # shown next to the picture and used for initials / alt text
    #     size: :md,                          # :sm, :md, :lg
    #     label: false                        # true (default when name is given) shows the name beside the picture
    #   }
    class AvatarFormatter < BaseFormatter
      SIZES = { sm: "h-6 w-6 text-xs", md: "h-8 w-8 text-sm", lg: "h-10 w-10 text-base" }.freeze
      COLORS = [
        "bg-indigo-100 dark:bg-indigo-900/40 text-indigo-700 dark:text-indigo-300", "bg-green-100 dark:bg-green-900/40 text-green-700 dark:text-green-300", "bg-yellow-100 dark:bg-yellow-900/40 text-yellow-700 dark:text-yellow-300",
        "bg-pink-100 dark:bg-pink-900/40 text-pink-700 dark:text-pink-300", "bg-blue-100 dark:bg-blue-900/40 text-blue-700 dark:text-blue-300", "bg-purple-100 dark:bg-purple-900/40 text-purple-700 dark:text-purple-300"
      ].freeze

      def format(value, record, options = {})
        name = resolve(options[:name], record)
        return "" if value.blank? && name.blank?

        size = SIZES.fetch((options[:size] || :md).to_sym, SIZES[:md])
        picture = image?(value) ? image(value, name, size) : initials(name, size)
        return picture if name.blank? || options[:label] == false

        content_tag(:div, safe_join([ picture, content_tag(:span, name.to_s, class: "truncate") ]), class: "flex items-center gap-2")
      end

      private

      def image?(value)
        Infotable::Formatters::LinkFormatter.safe_url?(value) && value.to_s.match?(%r{\A(https?:)?//|\A/})
      end

      def image(url, name, size)
        tag.img(src: url.to_s, alt: name.to_s, loading: "lazy", class: "#{size.split.first(2).join(' ')} rounded-full object-cover flex-none")
      end

      def initials(name, size)
        letters = name.to_s.split.first(2).map { _1[0] }.join.upcase.presence || "?"
        color = COLORS[name.to_s.sum % COLORS.size]
        content_tag(:span, letters, class: "inline-flex items-center justify-center rounded-full font-medium flex-none #{size} #{color}", "aria-hidden": "true")
      end

      def resolve(option, record)
        option.is_a?(Proc) ? view_context.instance_exec(record, &option) : option
      end
    end
  end
end
