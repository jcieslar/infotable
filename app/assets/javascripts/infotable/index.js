// InfoTable JavaScript entry point
// This works with any bundler: importmap, esbuild, webpack, vite, etc.

import TableController from "./controllers/table_controller";
import DrawerController from "./controllers/drawer_controller";

// Export controllers for manual registration
export { TableController, DrawerController };

// Auto-register function for convenience
export function registerInfotableControllers(application) {
  application.register("infotable--table", TableController);
  application.register("infotable--drawer", DrawerController);
}
