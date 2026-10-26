import { Controller } from "@hotwired/stimulus"
import Sortable from "sortablejs"

// Drawer controller for the filter drawer and column visibility
// Handles opening/closing the right-side drawer with smooth animations
export default class extends Controller {
  static targets = ["rail", "drawer", "content", "tabButton", "tabContent", "panelTitle", "columnBadge", "columnList"]
  static values = {
    open: { type: Boolean, default: false },
    currentTab: { type: String, default: "filters" }
  }

  connect() {
    // Close drawer on escape key
    this.boundCloseOnEscape = this.closeOnEscape.bind(this)
    document.addEventListener("keydown", this.boundCloseOnEscape)

    // Close drawer when clicking outside
    this.boundCloseOnClickOutside = this.closeOnClickOutside.bind(this)

    // Determine default tab based on which tab content is visible by default
    // If filters tab doesn't exist, default to columns tab
    const hasFiltersTab = this.tabContentTargets.some(content => content.dataset.tab === "filters")
    if (!hasFiltersTab && this.currentTabValue === "filters") {
      this.currentTabValue = "columns"
    }

    // Initialize to show appropriate tab by default
    this.switchTabTo(this.currentTabValue)

    // Initialize debounced filter submission
    this.debounceTimer = null
    this.debounceDelay = 500 // 500ms delay

    // Set up debounced filter inputs
    this.setupDebouncedFilters()

    // Initialize Sortable for column ordering
    this.initializeSortable()
  }

  openValueChanged() {
    if (this.openValue) {
      this.showDrawer()
      // Show appropriate tab by default when opening
      if (!this.currentTabValue) {
        const hasFiltersTab = this.tabContentTargets.some(content => content.dataset.tab === "filters")
        this.currentTabValue = hasFiltersTab ? "filters" : "columns"
      } else {
        this.switchTabTo(this.currentTabValue)
      }
      // Sync checkboxes and order with localStorage when drawer opens
      if (this.currentTabValue === "columns") {
        this.syncColumnCheckboxes()
        this.syncColumnListOrder()
      } else {
        // Update badge even if not on columns tab, so it's ready when switching
        setTimeout(() => {
          this.updateAllColumnBadges()
        }, 50)
      }
      // Setup debounced filters when drawer opens (in case form is rendered dynamically)
      setTimeout(() => {
        this.setupDebouncedFilters()
      }, 50)
      // Add click outside listener when drawer opens
      // Use setTimeout to avoid immediate closure from the click that opened it
      setTimeout(() => {
        document.addEventListener("click", this.boundCloseOnClickOutside)
      }, 100)
    } else {
      this.hideDrawer()
      // Reset to appropriate default tab when closing
      const hasFiltersTab = this.tabContentTargets.some(content => content.dataset.tab === "filters")
      this.currentTabValue = hasFiltersTab ? "filters" : "columns"
      // Remove click outside listener when drawer closes
      document.removeEventListener("click", this.boundCloseOnClickOutside)
    }
  }

  currentTabValueChanged() {
    if (this.currentTabValue) {
      this.switchTabTo(this.currentTabValue)
    }
  }

  disconnect() {
    document.removeEventListener("keydown", this.boundCloseOnEscape)
    document.removeEventListener("click", this.boundCloseOnClickOutside)

    // Clear debounce timer on disconnect
    if (this.debounceTimer) {
      clearTimeout(this.debounceTimer)
    }

    // Remove filter input listeners
    const form = this.contentTarget?.querySelector("form")
    if (form && this.boundHandleFilterInput) {
      form.removeEventListener('input', this.boundHandleFilterInput, true)
      form.removeEventListener('change', this.boundHandleFilterInput, true)
    }

    // Destroy Sortable instances
    if (this.sortableInstances) {
      this.sortableInstances.forEach(sortable => sortable.destroy())
      this.sortableInstances.clear()
    }
  }

  toggle() {
    this.openValue = !this.openValue
  }

  open() {
    // Default to appropriate tab when opening
    if (!this.currentTabValue) {
      const hasFiltersTab = this.tabContentTargets.some(content => content.dataset.tab === "filters")
      this.currentTabValue = hasFiltersTab ? "filters" : "columns"
    }
    this.openValue = true
  }

  close() {
    this.openValue = false
  }

  // Open drawer with columns tab (kept for backward compatibility)
  openColumns(event) {
    if (event) {
      event.preventDefault()
      event.stopPropagation()
    }
    this.currentTabValue = "columns"
    this.openValue = true
  }

  // Open drawer with filters tab (kept for backward compatibility)
  openFilters(event) {
    if (event) {
      event.preventDefault()
      event.stopPropagation()
    }
    this.currentTabValue = "filters"
    this.openValue = true
  }



  // Rail buttons: open the tab, or collapse the drawer when that tab is already showing
  toggleFilters(event) {
    this.toggleTab(event, "filters")
  }

  toggleColumns(event) {
    this.toggleTab(event, "columns")
  }

  // Click on the rail itself (outside its buttons): toggle the drawer on its default tab
  toggleRail(event) {
    if (event.target.closest("button, a")) return

    const hasFiltersTab = this.tabContentTargets.some(content => content.dataset.tab === "filters")
    this.toggleTab(event, hasFiltersTab ? "filters" : "columns")
  }

  toggleTab(event, tab) {
    event?.preventDefault()
    if (this.openValue && this.currentTabValue === tab) {
      this.openValue = false
    } else {
      this.currentTabValue = tab
      this.openValue = true
    }
  }

  showDrawer() {
    // Slide in drawer from its side using inline transform
    this.previouslyFocused = document.activeElement
    this.drawerTarget.inert = false
    this.drawerTarget.removeAttribute("aria-hidden")
    this.drawerTarget.style.transform = "translateX(0)"
    this.shiftRail(true)
    this.drawerTarget.querySelector("input:not([type=hidden]), select, button")?.focus({ preventScroll: true })
  }

  hideDrawer() {
    this.drawerTarget.inert = true
    this.drawerTarget.setAttribute("aria-hidden", "true")
    if (this.previouslyFocused?.isConnected) this.previouslyFocused.focus({ preventScroll: true })
    this.previouslyFocused = null

    // Slide out drawer to its side (data-drawer-side) using inline transform
    this.drawerTarget.style.transform = this.drawerTarget.dataset.drawerSide === "left" ? "translateX(-100%)" : "translateX(100%)"
    this.shiftRail(false)
  }

  // `toolbar :rail`: the rail slides left so it stays visible next to a right-hand drawer
  shiftRail(open) {
    if (!this.hasRailTarget || this.drawerTarget.dataset.drawerSide === "left") return

    this.railTarget.style.transform = open ? `translateX(-${this.drawerTarget.offsetWidth}px)` : ""
    this.railTarget.classList.toggle("shadow-lg", open)
  }

  closeOnEscape(event) {
    if (event.key === "Escape" && this.openValue) {
      this.close()
    }
  }

  closeOnClickOutside(event) {
    // Don't close if drawer is not open
    if (!this.openValue) {
      return
    }

    // Don't close if drawer target doesn't exist
    if (!this.hasDrawerTarget || !this.drawerTarget) {
      return
    }

    // Don't close if click is inside the drawer
    if (this.drawerTarget.contains(event.target)) {
      return
    }

    // The rail's buttons toggle the drawer themselves
    if (this.hasRailTarget && this.railTarget.contains(event.target)) {
      return
    }

    // Don't close if clicking on buttons that open the drawer
    const clickedElement = event.target.closest('button[data-action*="infotable--drawer#open"]')
    if (clickedElement) {
      return
    }

    // Don't close if clicking on elements inside buttons that open the drawer (like SVG icons)
    const buttonParent = event.target.closest('button')
    if (buttonParent && buttonParent.hasAttribute('data-action') && 
        buttonParent.getAttribute('data-action').includes('infotable--drawer#open')) {
      return
    }

    // Close the drawer when clicking outside (inside or outside the table)
    event.stopPropagation()
    this.close()
  }


  // Handle filter form submission
  submitFilters(event) {
    if (event) {
      event.preventDefault()
    }
    const form = event?.target || this.contentTarget.querySelector("form")
    if (!form) return
    
    const formData = new FormData(form)

    // Build URL with filter params
    const params = new URLSearchParams(formData)

    // Update the table via Turbo Frame
    const tableFrame = document.getElementById(form.dataset.tableFrame)

    // Keep search and sort from the current frame URL
    if (tableFrame?.src) {
      const current = new URL(tableFrame.src, window.location.href).searchParams
      for (const key of ["search", "per_page", "sort", "sort_column", "sort_direction"]) {
        if (current.has(key) && !params.has(key)) params.set(key, current.get(key))
      }
    }
    const url = form.action + "?" + params.toString()

    if (tableFrame) {
      tableFrame.src = url
      
      // Dispatch event to update export link after frame loads
      tableFrame.addEventListener("turbo:frame-load", () => {
        const tableName = form.action.match(/tables\/([^\/]+)/)?.[1]
        if (tableName) {
          document.dispatchEvent(new CustomEvent("infotable:filters-changed", {
            detail: { tableName }
          }))
        }
      }, { once: true })
    }
  }

  // Setup debounced filter inputs using event delegation
  setupDebouncedFilters() {
    // Find form in the drawer content (might be in filters tab)
    const form = this.contentTarget?.querySelector("form")
    if (!form) return

    // Check if autofilter is enabled (default: true)
    // HTML data attributes are strings, so check for string 'false'
    const autofilterValue = form.dataset.autofilter
    // If attribute is missing or is the string 'true', enable autofilter
    // Only disable if explicitly set to 'false'
    const autofilterEnabled = autofilterValue !== 'false'

    // Remove existing listeners if any (to avoid duplicates)
    if (this.boundHandleFilterInput) {
      form.removeEventListener('input', this.boundHandleFilterInput, true)
      form.removeEventListener('change', this.boundHandleFilterInput, true)
    }

    // Only setup debounced listeners if autofilter is enabled
    if (!autofilterEnabled) {
      return
    }

    // Create bound handler for event delegation
    this.boundHandleFilterInput = (event) => {
      const target = event.target
      // Only handle filter inputs (not hidden inputs, buttons, etc.)
      if (target.tagName === 'INPUT' && target.type === 'hidden') return
      if (target.tagName === 'BUTTON') return
      
      // Check if it's a filter input
      const isFilterInput = (
        (target.tagName === 'INPUT' && ['text', 'number', 'date'].includes(target.type)) ||
        target.tagName === 'SELECT'
      )
      
      if (isFilterInput) {
        this.debouncedSubmitFilters()
      }
    }

    // Use event delegation on the form for both input and change events
    // This handles all filter inputs without needing to attach individual listeners
    form.addEventListener('input', this.boundHandleFilterInput, true)
    form.addEventListener('change', this.boundHandleFilterInput, true)
  }

  // Debounced filter submission
  debouncedSubmitFilters() {
    // Clear existing timer
    if (this.debounceTimer) {
      clearTimeout(this.debounceTimer)
    }

    // Set new timer
    this.debounceTimer = setTimeout(() => {
      this.submitFilters(null)
    }, this.debounceDelay)
  }

  // Clear all filters
  clearFilters(event) {
    event.preventDefault()
    if (this.resetFilterInputs()) {
      // Submit immediately (no debounce for clear)
      this.submitFilters(null)
    }
  }

  // Empties every filter input in the drawer without reloading the table. False when there is no form.
  resetFilterInputs() {
    const form = this.contentTarget.querySelector("form")
    if (!form) return false

    // Clear debounce timer
    if (this.debounceTimer) {
      clearTimeout(this.debounceTimer)
      this.debounceTimer = null
    }

    // Reset all inputs except hidden ones (sort, per_page)
    form.querySelectorAll('input:not([type="hidden"]), select, textarea').forEach(input => {
      if (input.type === 'checkbox' || input.type === 'radio') {
        input.checked = false
      } else {
        input.value = ''
      }
    })

    this.syncFilterOps()
    return true
  }

  // Clear a single filter
  clearSingleFilter(event) {
    event.preventDefault()
    const button = event.currentTarget
    const filterName = button.dataset.filterName
    const filterType = button.dataset.filterType
    const form = this.contentTarget.querySelector("form")

    if (!form || !filterName) return

    // Controls are found by name inside this table's form, so ids may repeat across tables
    const field = (suffix) => form.querySelector(
      `[name="filters[${filterName}][${suffix}]"], [name="filters[${filterName}][${suffix}][]"]`
    )

    // Clear debounce timer
    if (this.debounceTimer) {
      clearTimeout(this.debounceTimer)
      this.debounceTimer = null
    }

    // Clear based on filter type
    switch (filterType) {
      case 'text':
        // Clear both operation and value
        const textOp = field('op')
        const textValue = field('value')
        if (textOp) textOp.value = 'contains'
        if (textValue) textValue.value = ''
        break

      case 'number':
      case 'date':
        // Back to the plain from/to range
        ;['from', 'to', 'value'].forEach(suffix => {
          const input = field(suffix)
          if (input) input.value = ''
        })
        const rangeOp = field('op')
        if (rangeOp) rangeOp.value = ''
        break

      case 'select':
        // Clear select value (single or multi)
        const selectInput = field('value')
        if (selectInput) {
          if (selectInput.multiple) {
            // Clear all selections in multi-select
            Array.from(selectInput.options).forEach(option => {
              option.selected = false
            })
          } else {
            // Reset to empty/default option
            selectInput.value = ''
          }
        }
        break

      case 'boolean':
        // Reset to "All" option
        const booleanInput = field('value')
        if (booleanInput) booleanInput.value = ''
        break

      default:
        // Generic clear for any other type
        const input = field('value')
        if (input) input.value = ''
    }

    this.syncFilterOps()

    // Submit immediately (no debounce for clear)
    this.submitFilters(null)
  }

  // Hide the value input for operators that take none (is_empty / is_not_empty)
  syncFilterOps() {
    this.syncRangeOps()
    this.element.querySelectorAll("select[data-filter-op]").forEach(select => {
      const container = select.closest("[data-filter-container]")
      const wrapper = container?.querySelector("[data-filter-value-wrapper]")
      if (!container || !wrapper) return

      const noValue = select.value === "is_empty" || select.value === "is_not_empty"
      if (noValue) wrapper.querySelector("input").value = ""
      wrapper.style.display = noValue ? "none" : "block"
      container.className = noValue ? "grid grid-cols-1 gap-2" : "grid grid-cols-[1fr_2fr] gap-2"
    })
  }

  // Number and date filters: the operator decides between from/to inputs, one value input, or none
  syncRangeOps() {
    this.element.querySelectorAll("select[data-range-op]").forEach(select => {
      const container = select.closest("[data-range-container]")
      if (!container) return

      const op = select.value
      const mode = op === "" ? "range" : (op === "is_empty" || op === "is_not_empty") ? "none" : "single"

      container.querySelectorAll("[data-range-fields]").forEach(group => {
        const visible = group.dataset.rangeFields === mode
        group.style.display = visible ? "" : "none"
        // inputs that are not shown must not leak into the request
        if (!visible) group.querySelectorAll("input").forEach(input => { input.value = "" })
      })
    })
  }

  // Tab switching
  switchTab(event) {
    event.preventDefault()
    const tab = event.currentTarget.dataset.tab
    this.currentTabValue = tab
  }

  switchTabTo(tab) {
    // Update tab buttons
    this.tabButtonTargets.forEach(button => {
      const isActive = button.dataset.tab === tab
      if (isActive) {
        button.classList.add("text-indigo-600", "dark:text-indigo-400", "border-indigo-600")
        button.classList.remove("text-gray-500", "dark:text-gray-400", "border-transparent")
      } else {
        button.classList.remove("text-indigo-600", "dark:text-indigo-400", "border-indigo-600")
        button.classList.add("text-gray-500", "dark:text-gray-400", "border-transparent")
      }
    })

    // Update tab content
    this.tabContentTargets.forEach(content => {
      if (content.dataset.tab === tab) {
        content.classList.remove("hidden")
      } else {
        content.classList.add("hidden")
      }
    })

    // Update panel title
    if (this.hasPanelTitleTarget) {
      if (tab === "columns") {
        this.panelTitleTarget.textContent = this.panelTitleTarget.dataset.columnsTitle || "Customize Columns"
      } else if (tab === "filters") {
        this.panelTitleTarget.textContent = this.panelTitleTarget.dataset.filtersTitle || "Filters"
      }
    }

    // Setup debounced filters when switching to filters tab
    if (tab === "filters") {
      setTimeout(() => {
        this.setupDebouncedFilters()
      }, 50)
    }

    // Sync column checkboxes and order with localStorage when switching to columns tab
    if (tab === "columns") {
      setTimeout(() => {
        this.syncColumnCheckboxes()
        // Sync column order in the drawer
        this.syncColumnListOrder()
        // Also update badge for all tables
        this.updateAllColumnBadges()
      }, 50)
    }
  }

  // Column visibility management
  updateColumnVisibility(event) {
    event.preventDefault()
    const checkbox = event.currentTarget
    const form = checkbox.closest("form")
    if (!form) return
    
    const tableName = form.dataset.tableName
    const columnName = checkbox.dataset.columnName
    const isVisible = checkbox.checked

    if (!tableName || !columnName) {
      console.warn("Missing tableName or columnName", { tableName, columnName })
      return
    }

    // Save to localStorage
    this.saveColumnVisibility(tableName, columnName, isVisible)

    // Apply visibility to table
    this.applyToTable(tableName)
    
    // Update badge
    this.updateColumnBadge(tableName)
    
    // Dispatch event to update export link
    document.dispatchEvent(new CustomEvent("infotable:columns-changed", {
      detail: { tableName }
    }))
  }

  selectAllColumns(event) {
    event.preventDefault()
    const tableName = event.currentTarget.dataset.tableName
    const form = document.getElementById(`column-visibility-form-${tableName}`)
    
    if (form) {
      const checkboxes = form.querySelectorAll('input[type="checkbox"]')
      checkboxes.forEach(checkbox => {
        checkbox.checked = true
        const columnName = checkbox.dataset.columnName
        this.saveColumnVisibility(tableName, columnName, true)
      })
      this.applyToTable(tableName)
      this.updateColumnBadge(tableName)
      
      // Dispatch event to update export link
      document.dispatchEvent(new CustomEvent("infotable:columns-changed", {
        detail: { tableName }
      }))
    }
  }

  deselectAllColumns(event) {
    event.preventDefault()
    const tableName = event.currentTarget.dataset.tableName
    const form = document.getElementById(`column-visibility-form-${tableName}`)
    
    if (form) {
      const checkboxes = form.querySelectorAll('input[type="checkbox"]')
      checkboxes.forEach(checkbox => {
        checkbox.checked = false
        const columnName = checkbox.dataset.columnName
        this.saveColumnVisibility(tableName, columnName, false)
      })
      this.applyToTable(tableName)
      this.updateColumnBadge(tableName)
      
      // Dispatch event to update export link
      document.dispatchEvent(new CustomEvent("infotable:columns-changed", {
        detail: { tableName }
      }))
    }
  }

  // Save column visibility to localStorage
  saveColumnVisibility(tableName, columnName, isVisible) {
    const key = `infotable_columns_${tableName}`
    let visibility = {}
    
    try {
      const stored = localStorage.getItem(key)
      if (stored) {
        visibility = JSON.parse(stored)
      }
    } catch (e) {
      console.warn("Failed to parse column visibility from localStorage", e)
    }

    visibility[columnName] = isVisible
    this.storeSet(key, JSON.stringify(visibility))
  }

  // Sync checkboxes with localStorage values or defaults
  syncColumnCheckboxes() {
    // Find all column visibility forms
    const forms = this.contentTarget.querySelectorAll('[id^="column-visibility-form-"]')
    forms.forEach(form => {
      const tableName = form.dataset.tableName
      const visibility = this.getColumnVisibility(tableName)

      // Update checkboxes based on saved preferences or defaults
      const checkboxes = form.querySelectorAll('input[type="checkbox"]')
      checkboxes.forEach(checkbox => {
        const columnName = checkbox.dataset.columnName
        if (visibility && visibility.hasOwnProperty(columnName)) {
          // Use saved preference from localStorage
          checkbox.checked = visibility[columnName]
        } else {
          // Use default visibility from data attribute
          const defaultVisible = checkbox.dataset.defaultVisible === "true"
          checkbox.checked = defaultVisible
        }
      })

      // Update badge after syncing
      this.updateColumnBadge(tableName)
    })
  }

  // Sync column list order in the drawer with localStorage
  syncColumnListOrder() {
    if (!this.hasColumnListTarget) return

    this.columnListTargets.forEach(list => {
      const tableName = list.dataset.tableName
      const defaultSchema = JSON.parse(list.dataset.columnsSchema || '[]')
      const storedOrder = this.loadColumnOrder(tableName)

      if (!storedOrder) {
        // No stored order, but still sync pin buttons with saved pinned state
        const pinnedData = this.getAllColumnsPinned(tableName)
        const columnItems = list.querySelectorAll('.column-item')
        columnItems.forEach(item => {
          const columnName = item.dataset.columnName
          const pinned = pinnedData[columnName] || null
          this.updatePinButtons(item, pinned)
        })
        return
      }

      // Validate stored order
      if (!this.isSchemaValid(storedOrder, defaultSchema)) {
        console.warn(`Schema mismatch for table ${tableName}, clearing stored order`)
        this.clearColumnOrder(tableName)
        return
      }

      // Apply order to the list
      this.applyColumnOrderToList(tableName, storedOrder)

      // Sync pin button styling with localStorage
      const pinnedData = this.getAllColumnsPinned(tableName)
      const columnItems = list.querySelectorAll('.column-item')
      columnItems.forEach(item => {
        const columnName = item.dataset.columnName
        const pinned = pinnedData[columnName] || null
        this.updatePinButtons(item, pinned)
      })
    })
  }

  // Get column visibility from localStorage
  getColumnVisibility(tableName) {
    const key = `infotable_columns_${tableName}`
    try {
      const stored = localStorage.getItem(key)
      return stored ? JSON.parse(stored) : null
    } catch (e) {
      console.warn("Failed to parse column visibility from localStorage", e)
      return null
    }
  }

  // The table controller applies order, visibility and pinning (it owns the table DOM); an explicit
  // `order` replaces the stored one (used right after a drag, a pin or a reset)
  applyToTable(tableName, order = null) {
    document.dispatchEvent(new CustomEvent("infotable:apply-columns", {
      detail: { tableName, order }
    }))
  }

  // Update column badge count for a specific table
  updateColumnBadge(tableName) {
    // Find the badge for this table using the data attribute
    const badge = Array.from(this.columnBadgeTargets || []).find(b => 
      b.dataset.badgeTableName === tableName
    )
    
    if (!badge) {
      // Fallback: find badge in tab button
      const tabButton = Array.from(this.tabButtonTargets).find(button => 
        button.dataset.tab === "columns" && button.dataset.tableName === tableName
      )
      if (tabButton) {
        const fallbackBadge = tabButton.querySelector('[data-badge-table-name="' + tableName + '"]')
        if (fallbackBadge) {
          this.updateBadgeText(fallbackBadge, tableName)
        }
      }
      return
    }
    
    this.updateBadgeText(badge, tableName)
  }

  // Helper method to update badge text
  updateBadgeText(badge, tableName) {
    // Find the form for this table
    const form = document.getElementById(`column-visibility-form-${tableName}`)
    if (!form) return
    
    // Count visible and total columns
    const checkboxes = form.querySelectorAll('input[type="checkbox"]')
    const totalColumns = checkboxes.length
    const visibleColumns = Array.from(checkboxes).filter(cb => cb.checked).length
    
    // Update badge text
    badge.textContent = `${visibleColumns} / ${totalColumns}`
  }

  // Update all column badges (useful when switching tabs)
  updateAllColumnBadges() {
    // Find all column visibility forms
    const forms = this.contentTarget?.querySelectorAll('[id^="column-visibility-form-"]')
    if (!forms) return

    forms.forEach(form => {
      const tableName = form.dataset.tableName
      if (tableName) {
        this.updateColumnBadge(tableName)
      }
    })
  }

  // ========== Column Pinning ==========

  // Handle pin button click
  pinColumn(event) {
    event.preventDefault()
    event.stopPropagation()

    const button = event.currentTarget
    const columnName = button.dataset.columnName
    const pinDirection = button.dataset.pinDirection
    const columnItem = button.closest('.column-item')
    const form = button.closest('form')

    if (!form || !columnName) return

    const tableName = form.dataset.tableName

    // Get current pinned state
    const currentPinned = this.getColumnPinned(tableName, columnName)

    // Toggle: if clicking same direction, unpin; otherwise, pin in that direction
    const newPinned = (currentPinned === pinDirection) ? null : pinDirection

    // Save to localStorage
    this.saveColumnPinned(tableName, columnName, newPinned)

    // Update button styling
    this.updatePinButtons(columnItem, newPinned)

    // Reorder columns in drawer based on pinned state
    this.reorderColumnsWithPinning(tableName)

    // Get the new order after pinning
    const list = Array.from(this.columnListTargets).find(l => l.dataset.tableName === tableName)
    if (list) {
      const columnItems = list.querySelectorAll('.column-item')
      const newOrder = Array.from(columnItems).map(item => item.dataset.columnName)

      // Order and sticky positioning, applied to the table immediately
      this.applyToTable(tableName, newOrder)
    }

    // Dispatch event for export link update
    document.dispatchEvent(new CustomEvent("infotable:columns-changed", {
      detail: { tableName }
    }))
  }

  // Save pinned state to localStorage
  saveColumnPinned(tableName, columnName, pinned) {
    const key = `infotable_column_pinned_${tableName}`
    let pinnedData = {}

    try {
      const stored = localStorage.getItem(key)
      if (stored) {
        pinnedData = JSON.parse(stored)
      }
    } catch (e) {
      console.warn("Failed to parse column pinned from localStorage", e)
    }

    // An unpin is stored as null (not removed): a column pinned by default must stay unpinned
    pinnedData[columnName] = pinned || null

    this.storeSet(key, JSON.stringify(pinnedData))
  }

  // localStorage is missing or full in some browsers (private mode): the drawer then works for this page only
  storeSet(key, value) {
    try {
      localStorage.setItem(key, value)
    } catch (e) {
      console.warn("Failed to write to localStorage", e)
    }
  }

  storeRemove(key) {
    try {
      localStorage.removeItem(key)
    } catch (e) {
      console.warn("Failed to write to localStorage", e)
    }
  }

  // Get pinned state from localStorage
  getColumnPinned(tableName, columnName) {
    return this.getAllColumnsPinned(tableName)[columnName] || null
  }

  // Pinned columns: what the user chose (localStorage) over the table's `pinned:` defaults.
  // A column the user unpinned is stored as null and stays unpinned.
  getAllColumnsPinned(tableName) {
    const key = `infotable_column_pinned_${tableName}`
    let stored = {}
    try {
      const raw = localStorage.getItem(key)
      if (raw) stored = JSON.parse(raw)
    } catch (e) {
      console.warn("Failed to parse column pinned from localStorage", e)
    }

    const pinned = {}
    const form = document.getElementById(`column-visibility-form-${tableName}`)
    form?.querySelectorAll('.column-item').forEach(item => {
      const defaultPinned = item.dataset.defaultPinned
      if (defaultPinned) pinned[item.dataset.columnName] = defaultPinned
    })
    return { ...pinned, ...stored }
  }

  // Update pin button styling
  updatePinButtons(columnItem, pinned) {
    const leftBtn = columnItem.querySelector('.pin-left')
    const rightBtn = columnItem.querySelector('.pin-right')

    if (leftBtn) {
      if (pinned === 'left') {
        leftBtn.classList.add('bg-indigo-100', 'dark:bg-indigo-900/40', 'text-indigo-600')
        leftBtn.classList.remove('text-gray-400', 'hover:bg-gray-100', 'dark:hover:bg-gray-700', 'hover:text-gray-600')
      } else {
        leftBtn.classList.remove('bg-indigo-100', 'dark:bg-indigo-900/40', 'text-indigo-600')
        leftBtn.classList.add('text-gray-400', 'hover:bg-gray-100', 'dark:hover:bg-gray-700', 'hover:text-gray-600')
      }
    }

    if (rightBtn) {
      if (pinned === 'right') {
        rightBtn.classList.add('bg-indigo-100', 'dark:bg-indigo-900/40', 'text-indigo-600')
        rightBtn.classList.remove('text-gray-400', 'hover:bg-gray-100', 'dark:hover:bg-gray-700', 'hover:text-gray-600')
      } else {
        rightBtn.classList.remove('bg-indigo-100', 'dark:bg-indigo-900/40', 'text-indigo-600')
        rightBtn.classList.add('text-gray-400', 'hover:bg-gray-100', 'dark:hover:bg-gray-700', 'hover:text-gray-600')
      }
    }
  }

  // Reorder columns in drawer based on pinning (left, unpinned, right)
  reorderColumnsWithPinning(tableName) {
    const list = Array.from(this.columnListTargets).find(l => l.dataset.tableName === tableName)
    if (!list) return

    const pinnedData = this.getAllColumnsPinned(tableName)
    const columnItems = Array.from(list.querySelectorAll('.column-item'))

    // Separate columns by pinned state
    const leftPinned = []
    const unpinned = []
    const rightPinned = []

    columnItems.forEach(item => {
      const columnName = item.dataset.columnName
      const pinned = pinnedData[columnName]

      if (pinned === 'left') {
        leftPinned.push(item)
      } else if (pinned === 'right') {
        rightPinned.push(item)
      } else {
        unpinned.push(item)
      }
    })

    // Reorder in DOM: left, unpinned, right
    leftPinned.forEach(item => list.appendChild(item))
    unpinned.forEach(item => list.appendChild(item))
    rightPinned.forEach(item => list.appendChild(item))

    // Save new order to localStorage
    const newOrder = [...leftPinned, ...unpinned, ...rightPinned].map(item => item.dataset.columnName)
    this.saveColumnOrder(tableName, newOrder)
  }

  // ========== Column Ordering with Drag and Drop ==========

  // Initialize Sortable for drag and drop column ordering
  initializeSortable() {
    if (!this.hasColumnListTarget) return

    this.columnListTargets.forEach(list => {
      const tableName = list.dataset.tableName
      const defaultSchema = JSON.parse(list.dataset.columnsSchema || '[]')

      // Validate stored schema and load column order
      this.validateAndLoadColumnOrder(tableName, defaultSchema)

      // Initialize Sortable.js
      const sortable = new Sortable(list, {
        animation: 150,
        handle: '.drag-handle',
        ghostClass: 'opacity-50',
        dragClass: 'shadow-lg',
        onEnd: (evt) => {
          this.handleColumnReorder(tableName, list, evt.item)
        }
      })

      // Store sortable instance for cleanup
      if (!this.sortableInstances) {
        this.sortableInstances = new Map()
      }
      this.sortableInstances.set(tableName, sortable)
    })
  }

  // Handle column reorder after drag and drop.
  // Pins survive a reorder; only the dragged column can change: dropped among the left pins it pins
  // left, among the right pins it pins right, anywhere else it is unpinned.
  handleColumnReorder(tableName, list, dragged) {
    const items = Array.from(list.querySelectorAll('.column-item'))
    const pinnedData = this.getAllColumnsPinned(tableName)

    if (dragged) {
      const at = items.indexOf(dragged)
      const nextPin = pinnedData[items[at + 1]?.dataset.columnName]
      const prevPin = pinnedData[items[at - 1]?.dataset.columnName]
      const pinned = nextPin === 'left' ? 'left' : (prevPin === 'right' ? 'right' : null)

      this.saveColumnPinned(tableName, dragged.dataset.columnName, pinned)
      this.updatePinButtons(dragged, pinned)
    }

    // Keep the list as left pins, the rest, right pins (this also saves the order)
    this.reorderColumnsWithPinning(tableName)
    const newOrder = Array.from(list.querySelectorAll('.column-item')).map(item => item.dataset.columnName)

    // Apply order and pins to the table
    this.applyToTable(tableName, newOrder)

    // Dispatch event for export link update
    document.dispatchEvent(new CustomEvent("infotable:columns-changed", {
      detail: { tableName }
    }))
  }

  // Save column order to localStorage
  saveColumnOrder(tableName, order) {
    const key = `infotable_column_order_${tableName}`
    this.storeSet(key, JSON.stringify(order))
  }

  // Load column order from localStorage
  loadColumnOrder(tableName) {
    const key = `infotable_column_order_${tableName}`
    try {
      const stored = localStorage.getItem(key)
      return stored ? JSON.parse(stored) : null
    } catch (e) {
      console.warn("Failed to parse column order from localStorage", e)
      return null
    }
  }

  // Validate stored schema against backend schema
  validateAndLoadColumnOrder(tableName, defaultSchema) {
    const storedOrder = this.loadColumnOrder(tableName)

    if (!storedOrder) {
      // No stored order, nothing to validate
      return
    }

    // Check if stored order matches backend schema
    const isValid = this.isSchemaValid(storedOrder, defaultSchema)

    if (!isValid) {
      // Schema mismatch - clear invalid localStorage
      console.warn(`Schema mismatch for table ${tableName}, clearing stored order`)
      this.clearColumnOrder(tableName)
      return
    }

    // Valid schema, apply the order
    this.applyColumnOrderToList(tableName, storedOrder)
    this.applyToTable(tableName, storedOrder)
  }

  // Check if stored order is valid against default schema
  isSchemaValid(storedOrder, defaultSchema) {
    // Extract column names from schema (handle both old and new formats)
    const schemaNames = defaultSchema.map(item =>
      typeof item === 'string' ? item : item.name
    )

    // Must have same length
    if (storedOrder.length !== schemaNames.length) {
      return false
    }

    // Must contain same columns (order can differ)
    const storedSet = new Set(storedOrder)
    const defaultSet = new Set(schemaNames)

    if (storedSet.size !== defaultSet.size) {
      return false
    }

    for (const col of storedOrder) {
      if (!defaultSet.has(col)) {
        return false
      }
    }

    return true
  }

  // Apply column order to the column list in the drawer
  applyColumnOrderToList(tableName, order) {
    const list = Array.from(this.columnListTargets).find(l => l.dataset.tableName === tableName)
    if (!list) return

    const columnItems = Array.from(list.querySelectorAll('.column-item'))
    const itemMap = new Map()

    // Create map of column name to DOM element
    columnItems.forEach(item => {
      itemMap.set(item.dataset.columnName, item)
    })

    // Reorder DOM elements according to order array
    order.forEach(columnName => {
      const item = itemMap.get(columnName)
      if (item) {
        list.appendChild(item)
      }
    })
  }

  // Clear column order from localStorage
  clearColumnOrder(tableName) {
    const key = `infotable_column_order_${tableName}`
    this.storeRemove(key)
  }

  // Reset to defaults - clear all custom settings
  resetToDefaults(event) {
    event.preventDefault()
    const tableName = event.currentTarget.dataset.tableName

    if (!tableName) return

    // Clear column visibility
    const visibilityKey = `infotable_columns_${tableName}`
    this.storeRemove(visibilityKey)

    // Clear column order
    this.clearColumnOrder(tableName)

    // Clear column pinning
    const pinnedKey = `infotable_column_pinned_${tableName}`
    this.storeRemove(pinnedKey)

    // Reset checkboxes to defaults
    const form = document.getElementById(`column-visibility-form-${tableName}`)
    if (form) {
      const checkboxes = form.querySelectorAll('input[type="checkbox"]')
      checkboxes.forEach(checkbox => {
        const defaultVisible = checkbox.dataset.defaultVisible === "true"
        checkbox.checked = defaultVisible
      })

      // Reset pin buttons to defaults
      const columnItems = form.querySelectorAll('.column-item')
      columnItems.forEach(item => {
        const defaultPinned = item.dataset.defaultPinned
        this.updatePinButtons(item, defaultPinned === 'left' ? 'left' : defaultPinned === 'right' ? 'right' : null)
      })

      // Reset column order in the drawer
      const defaultSchema = JSON.parse(form.dataset.columnsSchema || '[]')
      const schemaNames = defaultSchema.map(item => typeof item === 'string' ? item : item.name)
      this.applyColumnOrderToList(tableName, schemaNames)
    }

    // Apply the defaults (visibility, default order, default pinning) to the table
    const list = Array.from(this.columnListTargets).find(l => l.dataset.tableName === tableName)
    const defaultSchema = JSON.parse(list?.dataset.columnsSchema || '[]')
    this.applyToTable(tableName, list ? defaultSchema.map(item => typeof item === 'string' ? item : item.name) : null)

    // Update badge
    this.updateColumnBadge(tableName)

    // Dispatch event for export link update
    document.dispatchEvent(new CustomEvent("infotable:columns-changed", {
      detail: { tableName }
    }))

    // Show feedback (optional)
  }

}
