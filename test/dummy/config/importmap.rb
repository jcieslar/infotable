# Pin npm packages by running ./bin/importmap

pin "application"
pin "@hotwired/turbo-rails", to: "turbo.min.js"
pin "@hotwired/stimulus", to: "stimulus.min.js"
pin "@hotwired/stimulus-loading", to: "stimulus-loading.js"

# Pin infotable controllers
pin_all_from Infotable::Engine.root.join("app/assets/javascripts/infotable/controllers"),
  under: "controllers/infotable",
  to: "infotable/controllers"
