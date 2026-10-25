// Configure your import map in config/importmap.rb. Read more: https://github.com/rails/importmap-rails
import "@hotwired/turbo-rails"
import { Application } from "@hotwired/stimulus"
import { eagerLoadControllersFrom } from "@hotwired/stimulus-loading"

// Start Stimulus application
const application = Application.start()

// Configure Stimulus development experience
application.debug = true
window.Stimulus = application

// Load all controllers from infotable engine
import TableController from "controllers/infotable/table_controller"
import DrawerController from "controllers/infotable/drawer_controller"

application.register("infotable--table", TableController)
application.register("infotable--drawer", DrawerController)

console.log("InfoTable Dummy App loaded!")
console.log("Stimulus controllers registered:", Array.from(application.router.modulesByIdentifier.keys()))
