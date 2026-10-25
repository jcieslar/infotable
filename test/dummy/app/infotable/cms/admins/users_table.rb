# frozen_string_literal: true

# Zeitwerk autoloader infers Cms::Admins namespace from directory structure
# File: app/infotable/cms/admins/users_table.rb → Cms::Admins::UsersTable
class Cms::Admins::UsersTable < Infotable::Base
  # Data source - Admin users only
  query do
    User.where(status: "active")
  end

  # Column definitions
  column :id,
    label: "Admin ID",
    type: :integer,
    sortable: true,
    pinned: :left,
    width: "100px"

  column :name,
    label: "Admin Name",
    type: :string,
    sortable: true,
    searchable: true,
    filterable: true,
    filter_type: :text

  column :email,
    label: "Admin Email",
    type: :string,
    sortable: true

  column :company,
    label: "Company",
    type: :string,
    sortable: true,
    filterable: true,
    filter_type: :select,
    filter_options: -> { User.distinct.pluck(:company).compact.sort }

  column :actions,
    label: "Actions",
    type: :action,
    pinned: :right,
    formatter: :action,
    formatter_options: {
      actions: [
        {
          label: "View",
          url: ->(record) { "#admin-#{record.id}" },
          color: "primary"
        }
      ]
    }

  # Pagination settings
  per_page 15
  default_sort :name, :asc

  # Use slim rows for compact view
  slim_rows true
end
