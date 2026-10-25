# Pin infotable JavaScript modules
pin "infotable", to: "infotable/index.js"
pin_all_from Infotable::Engine.root.join("app/assets/javascripts/infotable/controllers"), under: "controllers/infotable", to: "infotable/controllers"

# External dependencies, served with the gem (no third-party CDN at runtime)
pin "sortablejs", to: "infotable/vendor/sortable.esm.js"
