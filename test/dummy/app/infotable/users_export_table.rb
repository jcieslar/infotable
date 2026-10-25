# Showcase for CSV export options: export_columns picks and orders the columns,
# exportable: false keeps one out, action columns are never exported.
class UsersExportTable < Infotable::Base
  query { User.all }

  column :id, type: :integer, visible: false
  column :name, label: "Name", sortable: true
  column :email, label: "Email"
  column :age, label: "Age", type: :integer, exportable: false
  column :company, label: "Company"
  column :actions, label: "Actions", type: :action, formatter: :action, formatter_options: { actions: [ { label: "View", url: ->(r) { "#user-#{r.id}" } } ] }

  export_columns :email, :name, :company
end
