Infotable::Engine.routes.draw do
  # Main table routes
  get "tables/:table_name", to: "tables#show", as: :table
  get "tables/:table_name/data", to: "tables#data", as: :table_data
  get "tables/:table_name/export", to: "tables#export", as: :table_export
  get "tables/:table_name/ids", to: "tables#ids", as: :table_ids
end
