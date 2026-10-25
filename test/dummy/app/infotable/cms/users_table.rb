# frozen_string_literal: true

# Zeitwerk autoloader infers Cms namespace from directory structure
# File: app/infotable/cms/users_table.rb → Cms::UsersTable
class Cms::UsersTable < Infotable::Base
  # Data source - using ActiveRecord relation
  query do
    User.all
  end

  # Column definitions - simplified for demonstration
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
    visible: true

  column :email,
    label: "Email",
    type: :string,
    sortable: true,
    visible: true

  column :status,
    label: "Status",
    type: :badge,
    sortable: true,
    visible: true,
    formatter: :badge,
    formatter_options: {
      colors: {
        active: "green",
        inactive: "gray",
        pending: "yellow"
      }
    }

  column :created_at,
    label: "Joined",
    type: :datetime,
    sortable: true,
    visible: true,
    formatter: :date,
    formatter_options: { format: :short }

  # Pagination settings
  per_page 10
  default_sort :created_at, :desc
end
