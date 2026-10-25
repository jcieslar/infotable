import { Controller } from "@hotwired/stimulus"

// Main table controller that coordinates table interactions
export default class extends Controller {
  static values = {
    name: String,
    urlState: Boolean
  }

  static targets = ["exportButton", "exportButtonText", "selectAll", "rowCheckbox", "batchBar", "batchCount"]

  // Target callbacks (rowCheckboxTargetConnected) can fire before connect(), so state lives here
  initialize() {
    this.selected = new Set()
    this.selectionScope = null
  }

  connect() {
    // Apply column order from localStorage first (must be before visibility)
    this.applyColumnOrder()

    // Apply column visibility from localStorage when table loads
    this.applyColumnVisibility()

    // Apply column pinning (sticky positioning)
    this.applyColumnPinning()

    // Update export link with current visible columns
    this.updateExportLink()

    // Fill the search box and the filter drawer from the page URL (the server already loaded the frame with it)
    if (this.urlStateValue) this.applyUrlStateToControls()

    // Listen for turbo frame loads to reapply order and visibility
    this.boundApplyOrderAndVisibility = this.applyOrderAndVisibility.bind(this)
    this.element.addEventListener("turbo:frame-load", this.boundApplyOrderAndVisibility)

    // Listen for column visibility changes to update export link
    this.boundUpdateExportLink = this.updateExportLink.bind(this)
    document.addEventListener("infotable:columns-changed", this.boundUpdateExportLink)
    document.addEventListener("infotable:filters-changed", this.boundUpdateExportLink)
  }

  disconnect() {
    this.element.removeEventListener("turbo:frame-load", this.boundApplyOrderAndVisibility)
    document.removeEventListener("infotable:columns-changed", this.boundUpdateExportLink)
    document.removeEventListener("infotable:filters-changed", this.boundUpdateExportLink)
    clearTimeout(this.searchTimeout)
  }

  // Apply both order and visibility (used for turbo frame loads)
  applyOrderAndVisibility() {
    this.applyColumnOrder()
    this.applyColumnVisibility()
    this.applyColumnPinning()
  }

  // Handle loading states
  beforeFetchRequest(event) {
    this.showLoading()
  }

  afterFetchResponse(event) {
    this.hideLoading()
  }

  // Handle turbo frame load
  handleFrameLoad(event) {
    this.syncSelectionScope(event.target)
    if (this.urlStateValue && event.target.id === `${this.nameValue}_content`) this.syncUrl(event.target)
  }

  // ---- Table state in the address bar ---------------------------------------
  // The frame URL (`/infotable/tables/users_table/data?filters[..]&sort=..&page=2`) is mirrored in the
  // page URL as `?users_table[filters][..]=..&users_table[page]=2`, one namespace per table. The
  // server reads it back when it renders the page (infotable_initial_state). Back/forward go through
  // Turbo's normal history handling, which re-renders the page from that URL.

  // "filters[name][op]" -> "users_table[filters][name][op]"
  toUrlKey(key) {
    const [, head, rest] = key.match(/^([^\[]+)(.*)$/)
    return `${this.nameValue}[${head}]${rest}`
  }

  // "users_table[filters][name][op]" -> "filters[name][op]" (nil when it belongs to another table)
  fromUrlKey(key) {
    const prefix = `${this.nameValue}[`
    if (!key.startsWith(prefix)) return null
    const [, head, rest] = key.slice(this.nameValue.length).match(/^\[([^\]]*)\](.*)$/) || []
    return head ? head + rest : null
  }

  // This table's state from the page URL, as plain frame params
  urlStateParams() {
    const state = new URLSearchParams()
    for (const [key, value] of new URLSearchParams(window.location.search)) {
      const inner = this.fromUrlKey(key)
      if (inner) state.append(inner, value)
    }
    return state
  }

  syncUrl(frame) {
    if (!frame.src) return

    const next = new URL(window.location.href)
    for (const key of Array.from(next.searchParams.keys())) {
      if (key.startsWith(`${this.nameValue}[`)) next.searchParams.delete(key)
    }

    const framePath = new URL(frame.src, window.location.href)
    for (const [key, value] of framePath.searchParams) {
      if (value === "" || key === "format" || key === "table_name") continue
      if (key === "page" && value === "1") continue
      next.searchParams.append(this.toUrlKey(key), value)
    }

    if (next.search === window.location.search) {
      this.urlStateStarted = true
      return
    }

    // The first change on a fresh page replaces the entry, later ones add entries for Back
    const state = { turbo: { restorationIdentifier: crypto.randomUUID() } }
    if (this.urlStateStarted) {
      window.history.pushState(state, "", next)
    } else {
      window.history.replaceState(window.history.state, "", next)
    }
    this.urlStateStarted = true
  }

  applyUrlStateToControls() {
    const state = this.urlStateParams()
    if (state.size === 0) return

    const search = this.element.querySelector('input[name="search"]')
    if (search && state.has("search")) search.value = state.get("search")

    const form = this.element.querySelector(`#filter-form-${CSS.escape(this.nameValue)}`)
    if (!form) return

    const names = new Set(Array.from(state.keys()).filter(key => key.startsWith("filters[")))
    names.forEach(name => {
      const values = state.getAll(name)
      form.querySelectorAll(`[name="${CSS.escape(name)}"]`).forEach(control => {
        if (control.tagName === "SELECT" && control.multiple) {
          Array.from(control.options).forEach(option => { option.selected = values.includes(option.value) })
        } else if (control.type === "checkbox" || control.type === "radio") {
          control.checked = values.includes(control.value)
        } else {
          control.value = values[0]
        }
      })
    })

    // Hide the value box for operators such as "is empty"
    // (the drawer controller may not be connected yet, so look it up on the next tick)
    setTimeout(() => {
      this.application.getControllerForElementAndIdentifier(this.element, "infotable--drawer")?.syncFilterOps()
    }, 0)
  }

  // ---- Batch selection ------------------------------------------------------
  // The selection survives page changes and infinite scroll. It is cleared when
  // the rows it refers to change meaning: a different search, filter or sort.

  syncSelectionScope(frame) {
    if (!frame?.src) return

    const params = new URL(frame.src, window.location.href).searchParams
    params.delete("page")
    params.delete("per_page")
    params.delete("format")
    params.sort()
    const scope = params.toString()

    if (this.selectionScope !== null && scope !== this.selectionScope) this.clearSelection()
    this.selectionScope = scope
  }

  // Fires for rows added later (next page, infinite scroll) so they pick up the selection
  rowCheckboxTargetConnected(checkbox) {
    checkbox.checked = this.selected.has(checkbox.value)
    this.renderSelection()
  }

  toggleRow(event) {
    const checkbox = event.currentTarget
    checkbox.checked ? this.selected.add(checkbox.value) : this.selected.delete(checkbox.value)
    this.renderSelection()
  }

  toggleAll(event) {
    const checked = event.currentTarget.checked
    this.rowCheckboxTargets.forEach(checkbox => {
      checkbox.checked = checked
      checked ? this.selected.add(checkbox.value) : this.selected.delete(checkbox.value)
    })
    this.renderSelection()
  }

  clearSelection() {
    this.selected.clear()
    this.rowCheckboxTargets.forEach(checkbox => { checkbox.checked = false })
    this.renderSelection()
  }

  renderSelection() {
    const count = this.selected.size

    if (this.hasBatchBarTarget) {
      this.batchBarTarget.classList.toggle("hidden", count === 0)
      this.batchBarTarget.classList.toggle("flex", count > 0)
    }
    if (this.hasBatchCountTarget) {
      this.batchCountTarget.textContent = this.batchCountTarget.dataset.template.replace("__COUNT__", count)
    }
    if (this.hasSelectAllTarget) {
      const boxes = this.rowCheckboxTargets
      const checkedOnPage = boxes.filter(box => box.checked).length
      this.selectAllTarget.checked = boxes.length > 0 && checkedOnPage === boxes.length
      this.selectAllTarget.indeterminate = checkedOnPage > 0 && checkedOnPage < boxes.length
    }

    this.element.dispatchEvent(new CustomEvent("infotable:selection-changed", {
      bubbles: true,
      detail: { table: this.nameValue, ids: Array.from(this.selected) }
    }))
  }

  // Sends the selected ids as ids[] to the action's URL. GET navigates; other verbs
  // submit a form (with Rails' _method override and the CSRF token).
  runBatchAction(event) {
    const button = event.currentTarget
    const ids = Array.from(this.selected)
    if (ids.length === 0) return

    const confirmText = button.dataset.batchConfirm
    if (confirmText && !window.confirm(confirmText.replace("%{count}", ids.length))) return

    const method = (button.dataset.batchMethod || "post").toLowerCase()
    const url = button.dataset.batchUrl

    if (method === "get") {
      const target = new URL(url, window.location.href)
      ids.forEach(id => target.searchParams.append("ids[]", id))
      window.Turbo ? window.Turbo.visit(target.toString()) : window.location.assign(target.toString())
      return
    }

    const form = document.createElement("form")
    form.method = "post"
    form.action = url
    form.hidden = true

    const field = (name, value) => {
      const input = document.createElement("input")
      input.type = "hidden"
      input.name = name
      input.value = value
      form.appendChild(input)
    }

    const csrf = document.querySelector('meta[name="csrf-token"]')?.content
    if (csrf) field("authenticity_token", csrf)
    if (method !== "post") field("_method", method)
    ids.forEach(id => field("ids[]", id))

    document.body.appendChild(form)
    form.requestSubmit()
    form.remove()
  }

  showLoading() {
    // Add loading indicator (to be enhanced in later phases)
    this.element.style.opacity = "0.6"
  }

  hideLoading() {
    this.element.style.opacity = "1"
  }

  // Shift+click on a sortable header adds/toggles the column in the multi-sort list
  // (sort=name:asc,age:desc). A plain click keeps the link's single-column behaviour.
  sortClick(event) {
    if (!event.shiftKey) return

    event.preventDefault()
    const column = event.currentTarget.dataset.sortColumn
    const frame = document.getElementById(`${this.nameValue}_content`)
    if (!frame || !column) return

    const url = new URL(frame.src || frame.getAttribute("src"), window.location.href)
    const params = url.searchParams

    let sorts = (params.get("sort") || "").split(",").filter(Boolean).map(item => item.split(":"))
    if (sorts.length === 0 && params.get("sort_column")) {
      sorts = [[params.get("sort_column"), params.get("sort_direction") || "asc"]]
    }

    const existing = sorts.find(([name]) => name === column)
    if (existing) {
      existing[1] = existing[1] === "asc" ? "desc" : "asc"
    } else {
      sorts.push([column, "asc"])
    }

    params.delete("sort_column")
    params.delete("sort_direction")
    params.set("sort", sorts.slice(0, 3).map(([name, dir]) => `${name}:${dir}`).join(","))
    params.set("page", "1")
    frame.src = url.toString()
  }

  // Debounced global search: reload the frame with ?search=, keeping sort/filters
  search(event) {
    clearTimeout(this.searchTimeout)
    const value = event.currentTarget.value.trim()

    this.searchTimeout = setTimeout(() => {
      const frame = document.getElementById(`${this.nameValue}_content`)
      if (!frame) return

      const url = new URL(frame.src || frame.getAttribute("src"), window.location.href)
      if (value) {
        url.searchParams.set("search", value)
      } else {
        url.searchParams.delete("search")
      }
      url.searchParams.set("page", "1")
      frame.src = url.toString()

      // Export link follows the frame's params
      frame.addEventListener("turbo:frame-load", () => this.updateExportLink(), { once: true })
    }, 300)
  }

  // Handle per-page change
  changePerPage(event) {
    const select = event.currentTarget
    const perPage = select.value
    const tableName = select.dataset.tableName

    // Build new URL with updated per_page parameter (keeps sort and filters)
    const params = new URLSearchParams(select.dataset.currentQuery || '')
    params.set('per_page', perPage)
    params.set('page', '1') // Reset to first page when changing per_page

    // Get the table frame and update its src
    const tableFrame = document.getElementById(`${tableName}_content`)
    if (tableFrame) {
      const baseUrl = tableFrame.src.split('?')[0]
      tableFrame.src = `${baseUrl}?${params.toString()}`
    }
  }

  // Apply column order from localStorage
  applyColumnOrder() {
    const tableName = this.nameValue
    const orderKey = `infotable_column_order_${tableName}`

    try {
      // Try to find table in the wrapper or in turbo-frame
      let table = this.element.querySelector("table")
      if (!table) {
        const turboFrame = document.getElementById(`${tableName}_content`)
        if (turboFrame) {
          table = turboFrame.querySelector("table")
        }
      }

      if (!table) {
        return
      }

      const headerRow = table.querySelector("thead tr")
      if (!headerRow) return

      const headers = Array.from(headerRow.querySelectorAll("th[data-column-name]"))
      if (headers.length === 0) return

      // Get default schema from current DOM order
      const defaultSchema = headers.map(h => h.dataset.columnName)

      // Load stored order from localStorage
      const storedOrder = this.loadColumnOrder(tableName)
      if (!storedOrder) return

      // Validate stored order against default schema
      if (!this.isSchemaValid(storedOrder, defaultSchema)) {
        console.warn(`Schema mismatch for table ${tableName}, clearing stored order`)
        this.clearColumnOrder(tableName)
        return
      }

      // Apply the order
      const headerMap = new Map()
      headers.forEach(header => {
        headerMap.set(header.dataset.columnName, header)
      })

      // Reorder headers
      storedOrder.forEach(columnName => {
        const header = headerMap.get(columnName)
        if (header) {
          headerRow.appendChild(header)
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

        storedOrder.forEach(columnName => {
          const cell = cellMap.get(columnName)
          if (cell) {
            row.appendChild(cell)
          }
        })
      })
    } catch (e) {
      console.warn("Failed to apply column order", e)
    }
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

  // Validate schema
  isSchemaValid(storedOrder, defaultSchema) {
    if (storedOrder.length !== defaultSchema.length) {
      return false
    }

    const storedSet = new Set(storedOrder)
    const defaultSet = new Set(defaultSchema)

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

  // Clear column order
  clearColumnOrder(tableName) {
    const key = `infotable_column_order_${tableName}`
    localStorage.removeItem(key)
  }

  // Apply column visibility from localStorage or use defaults
  applyColumnVisibility() {
    const tableName = this.nameValue
    const key = `infotable_columns_${tableName}`

    try {
      // Try to find table in the wrapper or in turbo-frame
      let table = this.element.querySelector("table")
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

      const headers = table.querySelectorAll("thead th[data-column-name]")
      const rows = table.querySelectorAll("tbody tr")

      if (headers.length === 0) {
        console.warn(`No column headers found for table: ${tableName}`)
        return
      }

      // Get saved preferences from localStorage
      let visibility = null
      const stored = localStorage.getItem(key)
      if (stored) {
        visibility = JSON.parse(stored)
      }

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
    } catch (e) {
      console.warn("Failed to apply column visibility", e)
    }

    // Update export link after applying visibility
    this.updateExportLink()
  }

  // Update export link with current visible columns and filters
  updateExportLink() {
    const tableName = this.nameValue
    const exportLink = this.element.querySelector('a[href*="/export"]')

    if (!exportLink) return

    // Get current visible columns from localStorage
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

    // Get all columns and determine which are visible
    // Try to find table in wrapper or turbo-frame
    let table = this.element.querySelector("table")
    if (!table) {
      const turboFrame = document.getElementById(`${tableName}_content`)
      if (turboFrame) {
        table = turboFrame.querySelector("table")
      }
    }

    if (!table) {
      // If table not found yet, use default visible columns from table class definition
      // We'll need to get this from the initial link or use all columns
      return
    }

    const headers = table.querySelectorAll("thead th[data-column-name]")
    const visibleColumns = []

    headers.forEach((header) => {
      const columnName = header.dataset.columnName
      const defaultVisible = header.dataset.defaultVisible === "true"

      // Determine if column should be visible
      let shouldShow
      if (visibility && visibility.hasOwnProperty(columnName)) {
        shouldShow = visibility[columnName]
      } else {
        shouldShow = defaultVisible
      }

      if (shouldShow) {
        visibleColumns.push(columnName)
      }
    })

    // Current filters/sort live in the turbo-frame src (drawer and sort links update it,
    // window.location is not touched)
    const frame = document.getElementById(`${tableName}_content`)
    const currentUrl = new URL(frame?.src || window.location.href, window.location.href)
    const params = new URLSearchParams()

    // Add visible columns
    if (visibleColumns.length > 0) {
      params.set('visible_columns', visibleColumns.join(','))
    }

    // Add filters from current URL (Rails nested params format: filters[column][op], filters[column][value])
    currentUrl.searchParams.forEach((value, key) => {
      if (key.startsWith('filters[')) {
        params.set(key, value)
      } else if (key === 'sort_column' || key === 'sort_direction' || key === 'sort' || key === 'search') {
        params.set(key, value)
      }
    })

    // Update export link
    const baseUrl = exportLink.href.split('?')[0]
    const queryString = params.toString()
    exportLink.href = queryString ? `${baseUrl}?${queryString}` : baseUrl
  }

  // Handle CSV export click - show brief loading state
  exportCsv(event) {
    const button = event.currentTarget
    const buttonText = button.querySelector('[data-infotable--table-target="exportButtonText"]')

    if (buttonText) {
      // Show loading state immediately
      button.classList.add('opacity-75', 'cursor-wait')
      const originalText = buttonText.textContent
      const exportingText = button.dataset.exportingText || 'Exporting...'
      buttonText.textContent = exportingText

      // Since CSV downloads are streamed and fast, reset quickly
      // The browser handles the download, we just provide visual feedback
      setTimeout(() => {
        button.classList.remove('opacity-75', 'cursor-wait')
        buttonText.textContent = originalText
      }, 500) // Brief feedback since streaming responses are fast
    }

    // Allow the default link behavior to proceed (download CSV)
    // The data-turbo="false" ensures Turbo doesn't intercept this
  }

  // Handle row click for clickable rows
  handleRowClick(event) {
    const row = event.currentTarget
    const url = row.dataset.rowLink

    if (!url) return

    // Don't navigate if clicking on interactive elements
    const target = event.target
    const tagName = target.tagName.toLowerCase()

    // Ignore clicks on links, buttons, inputs, selects, etc.
    if (tagName === "a" || tagName === "button" || tagName === "input" ||
        tagName === "select" || tagName === "textarea") {
      return
    }

    // Ignore clicks on elements inside buttons or links
    if (target.closest("a") || target.closest("button")) {
      return
    }

    // Navigate to the URL
    // Check if meta key (Cmd on Mac, Ctrl on Windows) is pressed for new tab
    if (event.metaKey || event.ctrlKey) {
      window.open(url, "_blank")
    } else {
      window.location.href = url
    }
  }

  // Apply column pinning (sticky positioning) from localStorage
  applyColumnPinning() {
    const tableName = this.nameValue
    const pinnedKey = `infotable_column_pinned_${tableName}`

    try {
      // Get pinned columns from localStorage
      let pinnedData = {}
      const stored = localStorage.getItem(pinnedKey)
      if (stored) {
        pinnedData = JSON.parse(stored)
      }

      // Try to find table in the wrapper or in turbo-frame
      let table = this.element.querySelector("table")
      if (!table) {
        const turboFrame = document.getElementById(`${tableName}_content`)
        if (turboFrame) {
          table = turboFrame.querySelector("table")
        }
      }

      if (!table) {
        console.warn(`Table not found for pinning: ${tableName}`)
        return
      }

      const headers = Array.from(table.querySelectorAll("thead th[data-column-name]"))

      // Columns the user never pinned/unpinned fall back to the table's `pinned:` default
      headers.forEach(header => {
        const name = header.dataset.columnName
        if (header.dataset.defaultPinned && !Object.prototype.hasOwnProperty.call(pinnedData, name)) {
          pinnedData[name] = header.dataset.defaultPinned
        }
      })
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
        header.style.removeProperty('background')
        header.style.removeProperty('background-color')
        header.style.removeProperty('background-image')
        header.style.removeProperty('background-position')
        header.style.removeProperty('background-size')
        header.style.removeProperty('background-repeat')
        header.style.removeProperty('background-attachment')
        header.style.removeProperty('opacity')
        header.style.backgroundClip = ''
        header.style.boxShadow = ''
        header.classList.remove('infotable-pinned-left', 'infotable-pinned-right', '!bg-gray-50', "after:content-['']", "after:absolute", "after:top-0", "after:right-0", "after:bottom-0", "after:w-5", "after:pointer-events-none", "after:bg-gradient-to-r", "after:from-transparent", "after:to-black/[0.04]", "after:z-[1]", "before:content-['']", "before:absolute", "before:top-0", "before:left-0", "before:bottom-0", "before:w-5", "before:pointer-events-none", "before:bg-gradient-to-l", "before:from-transparent", "before:to-black/[0.04]", "before:z-[1]")
      })

      rows.forEach(row => {
        const cells = row.querySelectorAll("td[data-column-name]")
        cells.forEach(cell => {
          cell.style.position = ''
          cell.style.left = ''
          cell.style.right = ''
          cell.style.zIndex = ''
          cell.style.removeProperty('background')
          cell.style.removeProperty('background-color')
          cell.style.removeProperty('background-image')
          cell.style.removeProperty('background-position')
          cell.style.removeProperty('background-size')
          cell.style.removeProperty('background-repeat')
          cell.style.removeProperty('background-attachment')
          cell.style.removeProperty('opacity')
          cell.style.backgroundClip = ''
          cell.style.boxShadow = ''
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
            top: 0px !important;
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
            background-clip: padding-box !important;
            box-shadow: 2px 0 4px -2px rgba(0, 0, 0, 0.1) !important;
            ${existingStyles}
          `.replace(/\s+/g, ' ').trim()

          // Set all styles at once via setAttribute (most aggressive method)
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
                background-clip: padding-box !important;
                box-shadow: 2px 0 4px -2px rgba(0, 0, 0, 0.1) !important;
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
            top: 0px !important;
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
            background-clip: padding-box !important;
            box-shadow: -2px 0 4px -2px rgba(0, 0, 0, 0.1) !important;
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
                background-clip: padding-box !important;
                box-shadow: -2px 0 4px -2px rgba(0, 0, 0, 0.1) !important;
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
    } catch (e) {
      console.warn("Failed to apply column pinning", e)
    }
  }
}
