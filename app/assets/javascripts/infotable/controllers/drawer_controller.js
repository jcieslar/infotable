import { Controller } from "@hotwired/stimulus"
import Sortable from "sortablejs"

// Drawer controller for the filter drawer and column visibility
// Handles opening/closing the right-side drawer with smooth animations
export default class extends Controller {
  static targets = ["drawer", "content", "tabButton", "tabContent", "panelTitle", "columnBadge", "columnList"]
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



  showDrawer() {
    // Slide in drawer from its side using inline transform
    this.previouslyFocused = document.activeElement
    this.drawerTarget.inert = false
    this.drawerTarget.removeAttribute("aria-hidden")
    this.drawerTarget.style.transform = "translateX(0)"
    this.drawerTarget.querySelector("input:not([type=hidden]), select, button")?.focus({ preventScroll: true })
  }

  hideDrawer() {
    this.drawerTarget.inert = true
    this.drawerTarget.setAttribute("aria-hidden", "true")
    if (this.previouslyFocused?.isConnected) this.previouslyFocused.focus({ preventScroll: true })
    this.previouslyFocused = null

    // Slide out drawer to its side (data-drawer-side) using inline transform
    this.drawerTarget.style.transform = this.drawerTarget.dataset.drawerSide === "left" ? "translateX(-100%)" : "translateX(100%)"
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
      for (const key of ["search", "sort", "sort_column", "sort_direction"]) {
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
        button.classList.add("text-indigo-600", "border-indigo-600")
        button.classList.remove("text-gray-500", "border-transparent")
      } else {
        button.classList.remove("text-indigo-600", "border-indigo-600")
        button.classList.add("text-gray-500", "border-transparent")
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
    this.applyColumnVisibility(tableName)
    
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
      this.applyColumnVisibility(tableName)
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
      this.applyColumnVisibility(tableName)
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
    localStorage.setItem(key, JSON.stringify(visibility))
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

  // Apply column visibility to the table
  applyColumnVisibility(tableName) {
    const tableWrapper = document.querySelector(`[data-infotable--table-name-value="${tableName}"]`)
    if (!tableWrapper) {
      console.warn(`Table wrapper not found for: ${tableName}`)
      return
    }

    // Try to find table in the wrapper or in turbo-frame
    let table = tableWrapper.querySelector("table")
    if (!table) {
      // Table might be inside turbo-frame
      const turboFrame = document.getElementById(`${tableName}_content`)
      if (turboFrame) {
        table = turboFrame.querySelector("table")
      }
    }
    
    if (!table) {
      console.warn(`Table not found for: ${tableName}`)
      return
    }

    // Find all table headers and cells
    const headers = table.querySelectorAll("thead th[data-column-name]")
    const rows = table.querySelectorAll("tbody tr")
    
    if (headers.length === 0) {
      console.warn(`No column headers found for table: ${tableName}`)
      return
    }
    
    // Get saved preferences from localStorage
    const visibility = this.getColumnVisibility(tableName)

    headers.forEach((header) => {
      const columnName = header.dataset.columnName
      const defaultVisible = header.dataset.defaultVisible === "true"
      
      // Determine if column should be visible
      let shouldShow
      if (visibility && visibility.hasOwnProperty(columnName)) {
        // Use saved preference
        shouldShow = visibility[columnName]
      } else {
        // Use default visibility
        shouldShow = defaultVisible
      }
      
      // Apply visibility
      header.style.display = shouldShow ? "" : "none"
      
      // Hide/show corresponding cells in all rows
      rows.forEach(row => {
        const cells = row.querySelectorAll("td[data-column-name]")
        const cell = Array.from(cells).find(c => c.dataset.columnName === columnName)
        if (cell) {
          cell.style.display = shouldShow ? "" : "none"
        }
      })
    })
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

      // Apply the new order to the table (reorders DOM)
      this.applyColumnOrder(tableName, newOrder)
    }

    // Apply sticky positioning to table immediately
    this.applyColumnPinningToTable(tableName)

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

    if (pinned) {
      pinnedData[columnName] = pinned
    } else {
      delete pinnedData[columnName]
    }

    localStorage.setItem(key, JSON.stringify(pinnedData))
  }

  // Get pinned state from localStorage
  getColumnPinned(tableName, columnName) {
    const key = `infotable_column_pinned_${tableName}`
    try {
      const stored = localStorage.getItem(key)
      if (stored) {
        const pinnedData = JSON.parse(stored)
        return pinnedData[columnName] || null
      }
    } catch (e) {
      console.warn("Failed to parse column pinned from localStorage", e)
    }
    return null
  }

  // Get all pinned columns
  getAllColumnsPinned(tableName) {
    const key = `infotable_column_pinned_${tableName}`
    try {
      const stored = localStorage.getItem(key)
      return stored ? JSON.parse(stored) : {}
    } catch (e) {
      console.warn("Failed to parse column pinned from localStorage", e)
      return {}
    }
  }

  // Update pin button styling
  updatePinButtons(columnItem, pinned) {
    const leftBtn = columnItem.querySelector('.pin-left')
    const rightBtn = columnItem.querySelector('.pin-right')

    if (leftBtn) {
      if (pinned === 'left') {
        leftBtn.classList.add('bg-indigo-100', 'text-indigo-600')
        leftBtn.classList.remove('text-gray-400', 'hover:bg-gray-100', 'hover:text-gray-600')
      } else {
        leftBtn.classList.remove('bg-indigo-100', 'text-indigo-600')
        leftBtn.classList.add('text-gray-400', 'hover:bg-gray-100', 'hover:text-gray-600')
      }
    }

    if (rightBtn) {
      if (pinned === 'right') {
        rightBtn.classList.add('bg-indigo-100', 'text-indigo-600')
        rightBtn.classList.remove('text-gray-400', 'hover:bg-gray-100', 'hover:text-gray-600')
      } else {
        rightBtn.classList.remove('bg-indigo-100', 'text-indigo-600')
        rightBtn.classList.add('text-gray-400', 'hover:bg-gray-100', 'hover:text-gray-600')
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

  // Apply pinning to table (add sticky positioning)
  applyColumnPinningToTable(tableName) {
    const tableWrapper = document.querySelector(`[data-infotable--table-name-value="${tableName}"]`)
    if (!tableWrapper) return

    let table = tableWrapper.querySelector("table")
    if (!table) {
      const turboFrame = document.getElementById(`${tableName}_content`)
      if (turboFrame) {
        table = turboFrame.querySelector("table")
      }
    }

    if (!table) return

    const pinnedData = this.getAllColumnsPinned(tableName)
    const headers = Array.from(table.querySelectorAll("thead th[data-column-name]"))
    const rows = table.querySelectorAll("tbody tr")

    // Calculate positions for pinned columns
    let leftOffset = 0
    let rightOffset = 0

    // First pass: reset all columns
    headers.forEach(header => {
      header.style.position = ''
      header.style.left = ''
      header.style.right = ''
      header.style.zIndex = ''
      header.style.removeProperty('background-color')
      header.style.removeProperty('background-image')
      header.style.removeProperty('opacity')
      header.classList.remove('infotable-pinned-left', 'infotable-pinned-right', '!bg-gray-50', "after:content-['']", "after:absolute", "after:top-0", "after:right-0", "after:bottom-0", "after:w-5", "after:pointer-events-none", "after:bg-gradient-to-r", "after:from-transparent", "after:to-black/[0.04]", "after:z-[1]", "before:content-['']", "before:absolute", "before:top-0", "before:left-0", "before:bottom-0", "before:w-5", "before:pointer-events-none", "before:bg-gradient-to-l", "before:from-transparent", "before:to-black/[0.04]", "before:z-[1]")
    })

    rows.forEach(row => {
      const cells = row.querySelectorAll("td[data-column-name]")
      cells.forEach(cell => {
        cell.style.position = ''
        cell.style.left = ''
        cell.style.right = ''
        cell.style.zIndex = ''
        cell.style.removeProperty('background-color')
        cell.style.removeProperty('background-image')
        cell.style.removeProperty('opacity')
        cell.classList.remove('infotable-pinned-left', 'infotable-pinned-right', '!bg-white', "after:content-['']", "after:absolute", "after:top-0", "after:right-0", "after:bottom-0", "after:w-5", "after:pointer-events-none", "after:bg-gradient-to-r", "after:from-transparent", "after:to-black/[0.04]", "after:z-[1]", "before:content-['']", "before:absolute", "before:top-0", "before:left-0", "before:bottom-0", "before:w-5", "before:pointer-events-none", "before:bg-gradient-to-l", "before:from-transparent", "before:to-black/[0.04]", "before:z-[1]")
      })
    })

    // Find last left-pinned and first right-pinned columns
    let lastLeftPinned = null
    let firstRightPinned = null

    headers.forEach(header => {
      const columnName = header.dataset.columnName
      const pinned = pinnedData[columnName]
      if (pinned === 'left') {
        lastLeftPinned = columnName
      }
      if (pinned === 'right' && !firstRightPinned) {
        firstRightPinned = columnName
      }
    })

    // Apply sticky positioning for pinned columns
    headers.forEach(header => {
      const columnName = header.dataset.columnName
      const pinned = pinnedData[columnName]

      if (pinned === 'left') {
        // Get existing inline styles
        const existingStyles = header.getAttribute('style') || ''

        // Build comprehensive style string with all !important flags
        const newStyles = `
          position: sticky !important;
          left: ${leftOffset}px !important;
          z-index: 30 !important;
          background: #f9fafb !important;
          background-color: #f9fafb !important;
          background-image: none !important;
          background-position: initial !important;
          background-size: initial !important;
          background-repeat: initial !important;
          background-attachment: initial !important;
          opacity: 1 !important;
          ${existingStyles}
        `.replace(/\s+/g, ' ').trim()

        // Set all styles at once via setAttribute
        header.setAttribute('style', newStyles)
        header.classList.add('infotable-pinned-left', '!bg-gray-50')

        // Mark last left-pinned column
        if (columnName === lastLeftPinned) {
          header.classList.add("after:content-['']", "after:absolute", "after:top-0", "after:right-0", "after:bottom-0", "after:w-5", "after:pointer-events-none", "after:bg-gradient-to-r", "after:from-transparent", "after:to-black/[0.04]", "after:z-[1]")
        }

        // Apply to cells in all rows
        rows.forEach(row => {
          const cell = row.querySelector(`td[data-column-name="${columnName}"]`)
          if (cell) {
            // Get existing inline styles
            const existingStyles = cell.getAttribute('style') || ''

            // Build comprehensive style string
            const newStyles = `
              position: sticky !important;
              left: ${leftOffset}px !important;
              z-index: 15 !important;
              background: #ffffff !important;
              background-color: #ffffff !important;
              background-image: none !important;
              background-position: initial !important;
              background-size: initial !important;
              background-repeat: initial !important;
              background-attachment: initial !important;
              opacity: 1 !important;
              ${existingStyles}
            `.replace(/\s+/g, ' ').trim()

            cell.setAttribute('style', newStyles)
            cell.classList.add('infotable-pinned-left', '!bg-white')

            if (columnName === lastLeftPinned) {
              cell.classList.add("after:content-['']", "after:absolute", "after:top-0", "after:right-0", "after:bottom-0", "after:w-5", "after:pointer-events-none", "after:bg-gradient-to-r", "after:from-transparent", "after:to-black/[0.04]", "after:z-[1]")
            }
          }
        })

        leftOffset += header.offsetWidth
      } else if (pinned === 'right') {
        // Get existing inline styles
        const existingStyles = header.getAttribute('style') || ''

        // Build comprehensive style string
        const newStyles = `
          position: sticky !important;
          right: ${rightOffset}px !important;
          z-index: 30 !important;
          background: #f9fafb !important;
          background-color: #f9fafb !important;
          background-image: none !important;
          background-position: initial !important;
          background-size: initial !important;
          background-repeat: initial !important;
          background-attachment: initial !important;
          opacity: 1 !important;
          ${existingStyles}
        `.replace(/\s+/g, ' ').trim()

        header.setAttribute('style', newStyles)
        header.classList.add('infotable-pinned-right', '!bg-gray-50')

        // Mark first right-pinned column
        if (columnName === firstRightPinned) {
          header.classList.add("before:content-['']", "before:absolute", "before:top-0", "before:left-0", "before:bottom-0", "before:w-5", "before:pointer-events-none", "before:bg-gradient-to-l", "before:from-transparent", "before:to-black/[0.04]", "before:z-[1]")
        }

        // Apply to cells in all rows
        rows.forEach(row => {
          const cell = row.querySelector(`td[data-column-name="${columnName}"]`)
          if (cell) {
            // Get existing inline styles
            const existingStyles = cell.getAttribute('style') || ''

            // Build comprehensive style string
            const newStyles = `
              position: sticky !important;
              right: ${rightOffset}px !important;
              z-index: 15 !important;
              background: #ffffff !important;
              background-color: #ffffff !important;
              background-image: none !important;
              background-position: initial !important;
              background-size: initial !important;
              background-repeat: initial !important;
              background-attachment: initial !important;
              opacity: 1 !important;
              ${existingStyles}
            `.replace(/\s+/g, ' ').trim()

            cell.setAttribute('style', newStyles)
            cell.classList.add('infotable-pinned-right', '!bg-white')

            if (columnName === firstRightPinned) {
              cell.classList.add("before:content-['']", "before:absolute", "before:top-0", "before:left-0", "before:bottom-0", "before:w-5", "before:pointer-events-none", "before:bg-gradient-to-l", "before:from-transparent", "before:to-black/[0.04]", "before:z-[1]")
            }
          }
        })

        rightOffset += header.offsetWidth
      }
    })
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
          this.handleColumnReorder(tableName, list)
        }
      })

      // Store sortable instance for cleanup
      if (!this.sortableInstances) {
        this.sortableInstances = new Map()
      }
      this.sortableInstances.set(tableName, sortable)
    })
  }

  // Handle column reorder after drag and drop
  handleColumnReorder(tableName, list) {
    // Get new order from DOM
    const columnItems = list.querySelectorAll('.column-item')
    const newOrder = Array.from(columnItems).map(item => item.dataset.columnName)

    // Unpin all columns when manually reordering
    const pinnedKey = `infotable_column_pinned_${tableName}`
    localStorage.removeItem(pinnedKey)

    // Update pin button styling for all items
    columnItems.forEach(item => {
      this.updatePinButtons(item, null)
    })

    // Save to localStorage
    this.saveColumnOrder(tableName, newOrder)

    // Apply order to table
    this.applyColumnOrder(tableName, newOrder)

    // Remove sticky positioning since all are unpinned
    this.applyColumnPinningToTable(tableName)

    // Dispatch event for export link update
    document.dispatchEvent(new CustomEvent("infotable:columns-changed", {
      detail: { tableName }
    }))
  }

  // Save column order to localStorage
  saveColumnOrder(tableName, order) {
    const key = `infotable_column_order_${tableName}`
    localStorage.setItem(key, JSON.stringify(order))
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
    this.applyColumnOrder(tableName, storedOrder)
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

  // Apply column order to the table
  applyColumnOrder(tableName, order) {
    const tableWrapper = document.querySelector(`[data-infotable--table-name-value="${tableName}"]`)
    if (!tableWrapper) return

    // Try to find table in the wrapper or in turbo-frame
    let table = tableWrapper.querySelector("table")
    if (!table) {
      const turboFrame = document.getElementById(`${tableName}_content`)
      if (turboFrame) {
        table = turboFrame.querySelector("table")
      }
    }

    if (!table) return

    // Get headers and create a map
    const headerRow = table.querySelector("thead tr")
    if (!headerRow) return

    const headers = Array.from(headerRow.querySelectorAll("th[data-column-name]"))
    const headerMap = new Map()

    headers.forEach((header, index) => {
      headerMap.set(header.dataset.columnName, { element: header, originalIndex: index })
    })

    // Reorder headers according to order array
    order.forEach(columnName => {
      const headerInfo = headerMap.get(columnName)
      if (headerInfo) {
        headerRow.appendChild(headerInfo.element)
      }
    })

    // Reorder cells in each row
    const rows = table.querySelectorAll("tbody tr")
    rows.forEach(row => {
      const cells = Array.from(row.querySelectorAll("td[data-column-name]"))
      const cellMap = new Map()

      cells.forEach(cell => {
        cellMap.set(cell.dataset.columnName, cell)
      })

      order.forEach(columnName => {
        const cell = cellMap.get(columnName)
        if (cell) {
          row.appendChild(cell)
        }
      })
    })
  }

  // Clear column order from localStorage
  clearColumnOrder(tableName) {
    const key = `infotable_column_order_${tableName}`
    localStorage.removeItem(key)
  }

  // Reset to defaults - clear all custom settings
  resetToDefaults(event) {
    event.preventDefault()
    const tableName = event.currentTarget.dataset.tableName

    if (!tableName) return

    // Clear column visibility
    const visibilityKey = `infotable_columns_${tableName}`
    localStorage.removeItem(visibilityKey)

    // Clear column order
    this.clearColumnOrder(tableName)

    // Clear column pinning
    const pinnedKey = `infotable_column_pinned_${tableName}`
    localStorage.removeItem(pinnedKey)

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

    // Apply defaults to table
    this.applyColumnVisibility(tableName)

    // Apply default column order to table
    const list = Array.from(this.columnListTargets).find(l => l.dataset.tableName === tableName)
    if (list) {
      const defaultSchema = JSON.parse(list.dataset.columnsSchema || '[]')
      const schemaNames = defaultSchema.map(item => typeof item === 'string' ? item : item.name)
      this.applyColumnOrder(tableName, schemaNames)
    }

    // Remove sticky positioning
    this.applyColumnPinningToTable(tableName)

    // Update badge
    this.updateColumnBadge(tableName)

    // Dispatch event for export link update
    document.dispatchEvent(new CustomEvent("infotable:columns-changed", {
      detail: { tableName }
    }))

    // Show feedback (optional)
  }

}
