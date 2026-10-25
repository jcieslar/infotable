class ProductsTable < Infotable::Base
  # Data source
  query do
    Product.all
  end

  # String columns
  column :id,
    label: "ID",
    type: :integer,
    sortable: true,
    visible: true

  column :name,
    label: "Product Name",
    type: :string,
    sortable: true,
    searchable: true,
    filterable: true,
    filter_type: :text,
    visible: true

  column :sku,
    label: "SKU",
    type: :string,
    sortable: true,
    searchable: true,
    filterable: true,
    filter_type: :text,
    visible: true,
    formatter: ->(value, record) { "<code class='px-2 py-1 bg-gray-100 rounded text-xs font-mono'>#{h(value)}</code>".html_safe }

  column :description,
    label: "Description",
    type: :text,
    visible: true,
    formatter: ->(value, record) {
      truncated = value.to_s.truncate(80)
      "<span class='text-gray-600 text-sm' title='#{h(value)}'>#{h(truncated)}</span>".html_safe
    }

  # Select/Category columns
  column :category,
    label: "Category",
    type: :string,
    sortable: true,
    filterable: true,
    filter_type: :select,
    filter_options: -> { Product.distinct.pluck(:category).compact.sort },
    visible: true,
    formatter: :badge,
    formatter_options: {
      colors: {
        "Electronics" => "blue",
        "Clothing" => "purple",
        "Home & Garden" => "green",
        "Sports & Outdoors" => "red",
        "Books" => "yellow",
        "Toys & Games" => "pink",
        "Health & Beauty" => "indigo",
        "Automotive" => "gray",
        "Food & Beverage" => "green",
        "Office Supplies" => "blue"
      }
    }

  column :manufacturer,
    label: "Manufacturer",
    type: :string,
    sortable: true,
    filterable: true,
    filter_type: :select,
    filter_options: -> { Product.distinct.pluck(:manufacturer).compact.sort },
    visible: true

  # Decimal/Currency columns
  column :price,
    label: "Price",
    type: :decimal,
    sortable: true,
    filterable: true,
    filter_type: :number,
    visible: true,
    formatter: :currency,
    formatter_options: { precision: 2 }

  column :cost,
    label: "Cost",
    type: :decimal,
    sortable: true,
    filterable: true,
    filter_type: :number,
    visible: true,
    formatter: :currency,
    formatter_options: { precision: 2 }

  # Integer column
  column :stock_quantity,
    label: "Stock",
    type: :integer,
    sortable: true,
    filterable: true,
    filter_type: :number,
    visible: true,
    formatter: ->(value, record) {
      color = if value.to_i == 0
        "red"
      elsif value < 50
        "yellow"
      else
        "green"
      end
      badge_class = case color
      when "red" then "bg-red-100 text-red-800 border-red-200"
      when "yellow" then "bg-yellow-100 text-yellow-800 border-yellow-200"
      when "green" then "bg-green-100 text-green-800 border-green-200"
      end
      "<span class='inline-flex items-center px-2.5 py-0.5 rounded-lg text-xs font-medium border #{badge_class}'>#{h(value)}</span>".html_safe
    }

  # Decimal rating
  column :rating,
    label: "Rating",
    type: :decimal,
    sortable: true,
    filterable: true,
    filter_type: :number,
    visible: true,
    formatter: ->(value, record) {
      return "-" if value.nil?
      stars = "⭐" * value.to_i
      "<span title='#{value}/5.0'>#{stars} #{number_with_precision(value, precision: 1)}</span>".html_safe
    }

  # Boolean columns
  column :active,
    label: "Active",
    type: :boolean,
    sortable: true,
    filterable: true,
    filter_type: :boolean,
    visible: true,
    formatter: :boolean

  column :featured,
    label: "Featured",
    type: :boolean,
    sortable: true,
    filterable: true,
    filter_type: :boolean,
    visible: true,
    formatter: :boolean

  # Date column
  column :manufactured_date,
    label: "Manufactured",
    type: :date,
    sortable: true,
    filterable: true,
    filter_type: :date,
    visible: true,
    formatter: :date,
    formatter_options: { format: :short }

  # DateTime column
  column :discontinued_at,
    label: "Discontinued",
    type: :datetime,
    sortable: true,
    filterable: true,
    filter_type: :date,
    visible: true,
    formatter: ->(value, record) {
      value ? "<span class='text-red-600 text-sm'>#{value.strftime('%Y-%m-%d')}</span>".html_safe : "<span class='text-gray-400'>-</span>".html_safe
    }

  column :created_at,
    label: "Created",
    type: :datetime,
    sortable: true,
    visible: false,
    formatter: :date,
    formatter_options: { format: :short }

  # Action column
  column :actions,
    label: "Actions",
    type: :action,
    visible: true,
    formatter: :action,
    formatter_options: {
      actions: [
        {
          label: "View",
          url: ->(record) { "#product-#{record.id}" },
          color: "primary"
        },
        {
          label: "Edit",
          url: ->(record) { "#edit-product-#{record.id}" }
        }
      ]
    }

  # Pagination settings
  per_page 25
  per_page_options [ 10, 25, 50, 100, 250 ]

  # Infinite scroll (default: false)
  # Set to true to enable infinite scrolling instead of pagination
  infinite_scroll true

  # Table height settings
  table_min_height "500px"
  table_max_height "700px"

  # Default sort
  default_sort :created_at, :desc

  # Use mid-size rows (between slim and default)
  row_size :mid
end
