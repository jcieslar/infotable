module Infotable
  # Row selection + bulk actions. The gem renders the checkboxes and the action bar;
  # the host app implements the endpoints and receives the ids as `ids[]`.
  #
  #   class PostsTable < Infotable::Base
  #     batch_actions do
  #       action :archive, label: "Archive", url: "/posts/archive", method: :patch
  #       action :delete,  label: "Delete",  url: "/posts/delete",  method: :delete,
  #                        confirm: "Delete %{count} posts?", color: :danger
  #     end
  #   end
  module BatchActions
    METHODS = %i[get post put patch delete].freeze
    COLORS = %i[default primary success warning danger].freeze

    class Builder
      attr_reader :actions

      def initialize
        @actions = []
      end

      def action(name, url:, label: nil, method: :post, confirm: nil, color: :default)
        method = method.to_s.downcase.to_sym
        color = color.to_s.to_sym
        raise ArgumentError, "batch action :#{name}: url must be a String" unless url.is_a?(String) && url.present?
        raise ArgumentError, "batch action :#{name}: method must be one of #{METHODS.inspect}" unless METHODS.include?(method)
        raise ArgumentError, "batch action :#{name}: color must be one of #{COLORS.inspect}" unless COLORS.include?(color)

        @actions << { name: name.to_sym, label: label || name.to_s.humanize, url: url, method: method, confirm: confirm, color: color }
      end
    end
  end
end
