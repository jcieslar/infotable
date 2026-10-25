# Pin infotable JavaScript modules
pin "infotable", to: "infotable/index.js"
pin_all_from Infotable::Engine.root.join("app/assets/javascripts/infotable/controllers"), under: "controllers/infotable", to: "infotable/controllers"

# External dependencies
pin "sortablejs", to: "https://cdn.jsdelivr.net/npm/sortablejs@1.15.7/modular/sortable.esm.js"
