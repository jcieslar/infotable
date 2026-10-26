module Infotable
  module Formatters
    # formatter: :image
    # A square thumbnail (use :avatar for round pictures); the value is the image URL.
    #   formatter_options: {
    #     size: :md,                        # :sm (32px), :md (48px), :lg (64px)
    #     alt: ->(record) { record.name },  # alt text, a String or a Proc
    #     link: true                        # open the full image in a new tab
    #   }
    class ImageFormatter < BaseFormatter
      SIZES = { sm: "h-8 w-8", md: "h-12 w-12", lg: "h-16 w-16" }.freeze

      def format(value, record, options = {})
        return "" unless image_url?(value)

        alt = options[:alt].is_a?(Proc) ? view_context.instance_exec(record, &options[:alt]) : options[:alt]
        size = SIZES.fetch((options[:size] || :md).to_sym, SIZES[:md])
        image = tag.img(src: value.to_s, alt: alt.to_s, loading: "lazy", class: "#{size} rounded-md object-cover flex-none")
        return image unless options[:link]

        link_to(image, value.to_s, target: "_blank", rel: "noopener noreferrer")
      end

      private

      def image_url?(value)
        LinkFormatter.safe_url?(value) && value.to_s.match?(%r{\A(https?:)?//|\A/})
      end
    end
  end
end
