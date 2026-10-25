class UsersTable < Infotable::Base
  # Data source - using ActiveRecord relation
  query do
    User.all
  end

  # Column definitions
  column :id,
    label: "ID",
    type: :integer,
    sortable: true,
    visible: true

  column :name,
    label: "Name",
    type: :string,
    sortable: true,
    searchable: true,
    filterable: true,
    filter_type: :text,
    visible: true,
    formatter: ->(value, record) { "<strong>#{h(value)}</strong>".html_safe }

  column :email,
    label: "Email",
    type: :string,
    sortable: true,
    searchable: true,
    filterable: true,
    filter_type: :text,
    visible: true

  column :company,
    label: "Company",
    type: :string,
    sortable: true,
    filterable: true,
    filter_type: :select,
    filter_options: -> { User.distinct.pluck(:company).compact.sort },
    visible: true

  column :status,
    label: "Status",
    type: :badge,
    sortable: true,
    filterable: true,
    filter_type: :select,
    filter_options: %w[active inactive pending],
    visible: true,
    formatter: :badge,
    formatter_options: {
      colors: {
        active: "green",
        inactive: "gray",
        pending: "yellow"
      }
    }

  column :age,
    label: "Age",
    type: :number,
    sortable: true,
    filterable: true,
    filter_type: :number,
    visible: true

  column :score,
    label: "Score",
    type: :number,
    sortable: true,
    filterable: true,
    filter_type: :number,
    visible: true,
    formatter: ->(value, record) { value ? number_with_precision(value, precision: 2) : "-" }

  column :salary,
    label: "Salary",
    type: :decimal,
    sortable: true,
    filterable: true,
    filter_type: :number,
    visible: true,
    formatter: :currency,
    formatter_options: { precision: 2 }

  column :created_at,
    label: "Joined",
    type: :datetime,
    sortable: true,
    filterable: true,
    filter_type: :date,
    visible: true,
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
          url: ->(record) { "#user-#{record.id}" },
          color: "primary"
        },
        {
          label: "Edit",
          url: ->(record) { "#edit-#{record.id}" }
        },
        {
          label: "Delete",
          url: ->(record) { "#delete-#{record.id}" },
          method: :delete,
          color: "danger",
          confirm: "Are you sure?"
        }
      ]
    }

  # Pagination settings
  per_page 10
  per_page_options [ 5, 10, 25, 50 ]

  # Table height settings (optional - will use global config if not set)
  table_min_height "500px"
  table_max_height "700px"

  # Default sort
  default_sort :created_at, :desc
end
