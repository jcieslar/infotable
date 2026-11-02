module Infotable
  module Formatters
    class BaseFormatter
      attr_reader :view_context

      def initialize(view_context)
        @view_context = view_context
      end

      # Override this in subclasses
      def format(value, record, options = {})
        value.to_s
      end

      protected

      # Helper methods available to all formatters
      def link_to(*args, &block)
        view_context.link_to(*args, &block)
      end

      def content_tag(*args, &block)
        view_context.content_tag(*args, &block)
      end

      def safe_join(*args)
        view_context.safe_join(*args)
      end

      def tag
        view_context.tag
      end

      def number_to_currency(*args)
        view_context.number_to_currency(*args)
      end

      def number_with_delimiter(*args)
        view_context.number_with_delimiter(*args)
      end

      def html_safe(str)
        str.to_s.html_safe
      end

      # Cells render inside the table's own <turbo-frame>, so a plain link would load its target into
      # that frame ("Content missing"). Default to the whole page; a given turbo_frame (any key
      # spelling: :turbo_frame, "turbo_frame", "turbo-frame") wins, e.g. a modal frame.
      def top_frame_data(data)
        data = (data || {}).to_h.transform_keys { |key| key.to_s.tr("-", "_").to_sym }
        data[:turbo_frame] = "_top" if data[:turbo_frame].blank?
        data
      end
    end
  end
end
