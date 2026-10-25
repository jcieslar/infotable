class AuthorsTable < Infotable::Base
  # Data source - using ActiveRecord relation
  query do
    Author.all
  end

  # Showcase: Compact table with custom widths for different data types
  column :id,
    label: "ID",
    type: :integer,
    width: "60px",  # Custom narrow width for IDs
    sortable: true,
    visible: true

  column :avatar_url,
    label: "",
    type: :string,
    width: "60px",
    visible: true,
    formatter: :avatar,
    formatter_options: { name: ->(record) { record.name }, label: false }

  column :name,
    label: "Author Name",
    type: :string,
    width: "250px",  # Custom width for names
    sortable: true,
    searchable: true,
    filterable: true,
    filter_type: :text,
    visible: true,
    formatter: ->(value, record) { "<strong>#{h(value)}</strong>".html_safe }

  column :email,
    label: "Email",
    type: :string,
    width: "280px",  # Wider for email addresses
    sortable: true,
    searchable: true,
    filterable: true,
    filter_type: :text,
    visible: true

  column :country,
    label: "Country",
    type: :string,
    sortable: true,
    filterable: true,
    filter_type: :select,
    filter_options: -> { Author.distinct.pluck(:country).compact.sort },
    visible: true

  column :verified,
    label: "Verified",
    type: :boolean,  # Uses default 80px width
    sortable: true,
    filterable: true,
    filter_type: :select,
    filter_options: [ [ "Yes", true ], [ "No", false ] ],
    visible: true,
    formatter: ->(value, record) {
      if value
        '<span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-green-100 text-green-800">✓ Verified</span>'.html_safe
      else
        '<span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-gray-100 text-gray-800">Unverified</span>'.html_safe
      end
    }

  column :followers_count,
    label: "Followers",
    type: :integer,  # Uses default 100px width
    sortable: true,
    visible: true,
    formatter: ->(value, record) {
      if value.nil?
        "-"
      elsif value >= 1000000
        "#{(value / 1000000.0).round(1)}M"
      elsif value >= 1000
        "#{(value / 1000.0).round(1)}K"
      else
        value.to_s
      end
    }

  column :website,
    label: "Website",
    type: :string,
    width: "200px",
    visible: true,
    formatter: :link,
    formatter_options: { external: true }

  column :created_at,
    label: "Joined",
    type: :datetime,  # Uses default 180px width
    sortable: true,
    filterable: true,
    filter_type: :date,
    visible: true,
    formatter: :date,
    formatter_options: { format: :short }

  column :actions,
    label: "Actions",
    type: :action,  # Uses default 100px width
    visible: true,
    formatter: :action,
    formatter_options: {
      actions: [
        {
          label: "View",
          url: ->(record) { "#author-#{record.id}" },
          color: "primary"
        },
        {
          label: "Edit",
          url: ->(record) { "#edit-author-#{record.id}" }
        }
      ]
    }

  # Table settings
  # Controls on a slim vertical rail instead of the header bar
  toolbar :rail

  per_page 25
  per_page_options [ 10, 25, 50, 100 ]
  default_sort :created_at, :desc
  table_min_height "400px"
  table_max_height "600px"

  # Slim rows - compact table with less padding
  slim_rows true
end
