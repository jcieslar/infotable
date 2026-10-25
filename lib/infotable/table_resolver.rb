module Infotable
  # Resolves a table name (:users_table, "cms_admins_users_table", "order_items_table")
  # to its Infotable::Base subclass.
  #
  # Underscores are ambiguous (namespace separator or word separator), so every way of
  # grouping the parts into namespaces is tried, flattest first:
  #   order_items -> OrderItemsTable, Order::ItemsTable, OrderItems::Table ...
  # Only classes inheriting from Infotable::Base are accepted.
  module TableResolver
    MAX_PARTS = 8

    class NotFound < Infotable::Error; end

    module_function

    def resolve(table_name)
      candidates(table_name).each do |class_name|
        klass = class_name.safe_constantize
        return klass if klass.is_a?(Class) && klass < Infotable::Base
      end

      raise NotFound, "Table '#{table_name}' not found. Make sure it's defined in app/infotable/"
    end

    CANDIDATES = Concurrent::Map.new

    # The class names to try are pure string work (up to 2**(n-1) of them): memoized per name
    def candidates(table_name)
      return [] unless table_name.to_s.match?(/\A[a-z0-9]+(_[a-z0-9]+)*\z/i)

      CANDIDATES.compute_if_absent(table_name.to_s) { build_candidates(table_name) }
    end

    def build_candidates(table_name)
      return [] unless table_name.to_s.match?(/\A[a-z0-9]+(_[a-z0-9]+)*\z/i)

      parts = table_name.to_s.sub(/_table\z/, "").split("_")
      return [] if parts.empty? || parts.size > MAX_PARTS

      (0...(2**(parts.size - 1))).map { |mask| segments(parts, mask) }
        .sort_by(&:size)
        .map { |segs| segs.map(&:camelize).join("::").sub(/([^:]+)\z/, '\1Table') }
        .uniq
    end

    # Bit i of mask set => split between part i and i+1
    def segments(parts, mask)
      parts.each_with_index.each_with_object([ [] ]) do |(part, i), acc|
        acc.last << part
        acc << [] if i < parts.size - 1 && mask[i] == 1
      end.map { |seg| seg.join("_") }
    end
  end
end
