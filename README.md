# InfoTable

Modern, flexible datatable engine for Rails 8+ with Hotwire. Build beautiful, interactive tables with server-side filtering, sorting, searching, and pagination—without page reloads.

**[Live demo](https://infotable.infovation.eu/)** · [Changelog](CHANGELOG.md) · [Contributing](CONTRIBUTING.md)

## Features

- ✨ **Server-side operations** - Filtering, sorting, searching, pagination all on the backend
- ⚡ **No page reloads** - Built with Hotwire (Turbo + Stimulus)
- 🎨 **Pure Tailwind CSS** - Beautiful, modern UI using only Tailwind utility classes (no custom CSS!)
- 🔧 **Highly customizable** - Easy to override defaults and add custom formatters
- 📦 **Works with any bundler** - Importmap, esbuild, webpack, vite—we support them all
- 🚀 **Rails 8+ ready** - Built for modern Rails applications
- 🌍 **i18n Support** - English, Polish, German, French, Spanish, Greek and Italian translations included
- 🎯 **Advanced Features** - Infinite scroll, column pinning, drag-to-reorder, row links, and more

## Quick Start

```ruby
# 1. Add to Gemfile
gem 'infotable'

# 2. Install
bundle install
rails generate infotable:install

# 3. Create a table definition (app/infotable/users_table.rb)
class UsersTable < Infotable::Base
  query { User.all }

  column :name, label: "Name", type: :string, sortable: true
  column :email, label: "Email", type: :string, sortable: true
  column :created_at, label: "Created", type: :datetime, sortable: true

  per_page 25
end

# 4. Use in your view
<%= infotable :users_table %>
```

That's it! You now have a fully functional datatable with sorting and pagination.

## Requirements

- Rails 8.0+
- Ruby 3.3+
- PostgreSQL or SQLite (other databases are not supported). On SQLite, text filters and search ignore case for ASCII letters only (`ś` does not match `Ś`); PostgreSQL matches all letters
- [Pagy](https://github.com/ddnexus/pagy) 43 (installed as a dependency)
- Tailwind CSS v4 (via `tailwindcss-rails` gem) - **Required for styling**
- Hotwire (Turbo + Stimulus)

**Note:** InfoTable uses pure Tailwind CSS utility classes for all styling. No custom CSS is included or required.

## Installation

### Automatic Installation (Recommended)

```bash
bundle add infotable
rails generate infotable:install
```

The installer will:
- Auto-detect your JavaScript bundler (importmap, esbuild, webpack, vite)
- Configure Tailwind CSS (v4 or v3) to scan InfoTable views
- Mount engine routes
- Create `app/infotable/` directory
- Generate configuration file

**After installation:**
```bash
# Rebuild Tailwind to include InfoTable styles
rails tailwindcss:build

# Restart your Rails server
rails server
```

**Important:** Verify your layout (`app/views/layouts/application.html.erb`) includes:
```erb
<%= stylesheet_link_tag "tailwind", "data-turbo-track": "reload" %>
```

### Manual Installation

See [docs/installation.md](docs/installation.md) for detailed instructions for each bundler type.

## Bundler Support

InfoTable works seamlessly with:
- **Importmap** (Rails default)
- **esbuild**
- **webpack**
- **vite**
- Other JavaScript bundlers

The installer automatically detects and configures your setup.

---

## Configuration

### Global Configuration

Customize in `config/initializers/infotable.rb`:

```ruby
Infotable.configure do |config|
  # Pagination defaults
  config.default_per_page = 25
  config.per_page_options = [10, 25, 50, 100]

  # Drawer/side panel settings
  config.drawer_position = :right  # :left or :right
  config.drawer_width = "26rem"  # px, rem, em, vw or %

  # Controller the engine controllers inherit from, so authentication, locale,
  # tenant scoping etc. also protect the tables
  config.parent_controller = "ApplicationController"

  # Table height defaults
  config.table_min_height = "400px"
  config.table_max_height = "600px"

  # Filter behavior
  config.autofilter = true  # true = auto-apply filters (debounced), false = manual apply button
end
```

### Security

Tables are served by the engine at `/infotable/tables/:name/{data,export,ids}`. A table without an
`authorize { |controller| ... }` block is readable (and exportable as CSV) by **everyone who can reach the
route**, unless the engine controllers inherit your app's authentication. The installer therefore sets
`config.parent_controller = "ApplicationController"`; keep it (or point it at a controller with your
`before_action :authenticate_user!`) and add `authorize` to tables with restricted data. The engine's own
default (`ActionController::Base`) applies no authentication at all.

### Available Global Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `default_per_page` | Integer | `25` | Default number of rows per page |
| `per_page_options` | Array | `[10, 25, 50, 100]` | Available rows per page options |
| `drawer_position` | Symbol | `:right` | Position of filter/column drawer (`:left` or `:right`) |
| `drawer_width` | String | `"26rem"` | Width of the drawer (`px`, `rem`, `em`, `vw` or `%`; anything else falls back to the default) |
| `parent_controller` | String | `"ActionController::Base"` (the installer sets `"ApplicationController"`) | Controller the engine's controllers inherit from. Set it to `"ApplicationController"` to reuse your authentication |
| `max_select_all` | Integer, nil | `4000` | "Select all N matching" collects at most this many ids (each is sent as `ids[]`; Rack accepts 4096 parameters per request) |
| `table_min_height` | String | `"400px"` | Minimum table height |
| `table_max_height` | String | `"600px"` | Maximum table height (enables scrolling) |
| `autofilter` | Boolean | `true` | Auto-apply filters on change (debounced) vs manual apply |
| `url_state` | Boolean | `true` | Mirror search, filters, sort and page in the address bar (override per table with `url_state false`) |
| `max_filter_options` | Integer | `500` | Cap on `<option>`s in a select filter (`nil` = no cap) |

`theme`, `turbo_enabled` and `pagination_gem` are still accepted so old initializers keep loading, but they do nothing.

---

## Table Definition

Generate a starting point from a model's columns:

```bash
rails generate infotable:table User
rails generate infotable:table Admin::Order --only=id number status   # or --skip=notes
rails generate infotable:table Order --per-page=50 --sort=placed_at:desc --toolbar=rail --checkbox \
  --authorize="controller.current_user&.admin?"   # also --row-click --infinite-scroll --countless
```

It writes `app/infotable/users_table.rb` with a column per attribute (types and filters inferred, enums become select filters, passwords/tokens and foreign keys are left out, `belongs_to` associations come as commented hints).

Or create table classes in `app/infotable/` by hand:

```ruby
class UsersTable < Infotable::Base
  # Define data source
  query { User.all }

  # Define columns
  column :name, label: "Full Name", type: :string, sortable: true

  # Configure table settings
  per_page 25
  default_sort :created_at, :desc
end
```

### Organizing Tables in Folders

You can organize table definitions in subfolders. Rails' Zeitwerk autoloader automatically creates namespaces from the directory structure:

**Single-level nesting:**
```ruby
# app/infotable/cms/users_table.rb
class Cms::UsersTable < Infotable::Base
  query { User.all }
  # ... columns
end

# Use in views:
<%= infotable :cms_users_table %>
```

**Multi-level nesting:**
```ruby
# app/infotable/cms/admins/users_table.rb
class Cms::Admins::UsersTable < Infotable::Base
  query { User.where(admin: true) }
  # ... columns
end

# Use in views:
<%= infotable :cms_admins_users_table %>
```

**How it works:**
- Rails' Zeitwerk autoloader infers namespaces from directory structure
- File path: `app/infotable/cms/users_table.rb` → Class: `Cms::UsersTable` → Symbol: `:cms_users_table`
- File path: `app/infotable/cms/admins/users_table.rb` → Class: `Cms::Admins::UsersTable` → Symbol: `:cms_admins_users_table`
- No need for `module` wrappers - the directory structure provides the namespace

**Naming convention:**
- Pattern: folder names joined with underscores, followed by the table name
- Example: folder `cms/admins` + file `users_table.rb` = symbol `:cms_admins_users_table`

### Data Source Methods

#### `query`
Define data source using ActiveRecord relation:

```ruby
query { User.includes(:company).where(active: true) }
```

The block receives the controller, so you can scope by the current user:

```ruby
query { |controller| controller.current_user.projects }
```

#### `query_sql`
Define data source using raw SQL. A `model:` is required; it supplies the column types and the table alias. The SQL is wrapped in a sub-select, so filters, search, sorting, pagination and export all work:

```ruby
query_sql "SELECT * FROM users WHERE active = true", model: User
```

#### `authorize`
Return false to answer `403 Forbidden` for the table, its data and its export:

```ruby
authorize { |controller| controller.current_user&.admin? }
```

### Column Definition

```ruby
column :name, **options
```

#### Virtual/Computed Columns

For aggregated or computed columns (COUNT, SUM, subqueries, calculations), mark them as `virtual: true`:

```ruby
query do
  Shop.select(
    "shops.*",
    "COUNT(products.id) AS products_count"
  )
    .left_joins(:products)
    .group("shops.id")
end

# Regular column
column :name, sortable: true, filterable: true

# Virtual column (aggregate)
column :products_count,
  type: :integer,
  sortable: true,        # ✅ Sorting works
  filterable: true,      # ✅ Filtering uses HAVING clause
  filter_type: :number,
  virtual: true,         # ⭐ Required for aggregates!
  virtual_sql: "COUNT(products.id)" # ⭐ SQL expression for filtering (without AS alias)
```

**Why `virtual: true` and `virtual_sql`?**
- Aggregated columns require `HAVING` clause for filtering (not `WHERE`)
- The `virtual_sql` option provides the SQL expression used in both HAVING and ORDER BY clauses
- InfoTable automatically uses the correct SQL clauses for filtering and sorting
- Works with all filter types
- See [docs/virtual_columns.md](docs/virtual_columns.md) for detailed examples

#### Column Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `label` | String | Humanized column name | Display label for column header |
| `type` | Symbol | `:string` | Data type (see Column Types below) |
| `sortable` | Boolean | `false` | Enable sorting for this column |
| `searchable` | Boolean | `false` | Include in global search |
| `filterable` | Boolean | `false` | Enable filtering for this column |
| `visible` | Boolean | `true` | Show column by default |
| `pinned` | Symbol | `nil` | Pin column (`:left`, `:right`, or `nil`) |
| `width` | String | Auto (see defaults) | Column width (e.g., `"200px"`) |
| `formatter` | Symbol/Proc/Hash | `nil` | Custom formatter (see Formatters) |
| `filter_type` | Symbol | Auto-detected | Filter UI type (`:text`, `:number`, `:date`, `:select`, `:boolean`) |
| `filter_options` | Array/Proc | `nil` | Options for select filters (`["a", "b"]`, `[["Label", value]]` or a Proc) |
| `filter_options_cache` | Duration | `nil` | Cache a Proc's result with `Rails.cache`, e.g. `5.minutes`. Keyed per table and column, so do not use it for options that depend on the current user |
| `filter_options_limit` | Integer | `max_filter_options` | Most `<option>`s rendered for this filter; the drawer says when the list was cut. For big lists use a text filter instead |
| `virtual` | Boolean | `false` | Mark column as virtual/computed (aggregates, subqueries) - uses HAVING for filters |
| `virtual_sql` | String | `nil` | SQL expression for virtual columns (used in HAVING and ORDER BY clauses, without AS alias) |
| `sql` | String | `nil` | Row-level SQL expression to filter and search on instead of the column (e.g. `"comments.post_id"`). Not an aggregate, so it goes in `WHERE` |
| `sort_sql` | String | `nil` | SQL expression to sort by (e.g. `"authors.name"` for an association column) |
| `value` | Proc | `nil` | Computes the cell value from the record: `value: ->(post) { post.author.name }` |
| `includes` | Symbol/Array/Hash | `nil` | Association to preload for this column (avoids N+1 in the table and the CSV export) |
| `filter_multi_select` | Boolean | `false` | Let a `:select` filter take several values |

#### Column Types

Available types and their default widths:

| Type | Default Width | Description |
|------|---------------|-------------|
| `:string` | `200px` | Text string |
| `:text` | `300px` | Long text content |
| `:integer` | `100px` | Integer number |
| `:decimal` | `120px` | Decimal number |
| `:float` | `120px` | Float number |
| `:currency` | `120px` | Currency value |
| `:boolean` | `80px` | True/false value |
| `:date` | `120px` | Date only |
| `:datetime` | `180px` | Date and time |
| `:badge` | `120px` | Badge/status indicator |
| `:status` | `120px` | Alias for badge |
| `:action` | `100px` | Action buttons |
| `:actions` | `100px` | Alias for action |

### Table Configuration Methods

#### Pagination

```ruby
# Set rows per page
per_page 25

# Set per-page options dropdown
per_page_options [10, 25, 50, 100]
```

#### Sorting

```ruby
# Set default sort
default_sort :created_at, :desc  # column, direction (:asc or :desc)
```

Click a header to sort; **Shift+click** adds up to three sort columns (`?sort=name:asc,age:desc`). The primary key is always appended as a tiebreaker, so pages never repeat or skip rows.

#### Search

Mark columns `searchable: true` to get a search box. Every word (up to 5) must match at least one searchable column, case-insensitively.

The box sits in the header bar. With `toolbar :rail` there is no header, so it moves to the top of the drawer: open it with the rail's filters or columns button. It works the same there (debounced, kept across sorting, filters and CSV export, restored from the URL) and is shown only when at least one column is `searchable`.

#### Filters

Filter types are inferred from the column type or set with `filter_type:`.

| Type | Operators |
|------|-----------|
| text | contains, equals, starts with, ends with, not contains, is empty, is not empty |
| number | `eq` `neq` `gt` `gte` `lt` `lte` `between` `is_empty` `is_not_empty` (plain `from`/`to` still work; the drawer shows them as "Between") |
| date | `on` `before` `after` `between` `is_empty` `is_not_empty` (plain `from`/`to` still work) |
| boolean | any, yes, no |
| select | one value, or several with `filter_multi_select: true` |

Filters, search and sort survive pagination, per-page changes and CSV export.

#### Table state in the URL

Search, filters, sort, page and page size are mirrored in the page's address bar, one namespace per table (`/users?users_table[search]=ann&users_table[page]=2`). Links can be shared and bookmarked, a reload keeps the table as it was, and the Back button steps through the states. Turn it off globally with `config.url_state = false` or per table with `url_state false` (e.g. tables inside modals or tabs).

#### Column widths, dark mode, small screens

- Every header has a drag handle on its right edge (keyboard: focus it, Left/Right, Shift for bigger steps; double-click resets). Widths are remembered in the browser. `resizable_columns false` removes the handles.
- Dark mode follows `prefers-color-scheme`. If your app switches with a `.dark` class instead, add `@custom-variant dark (&:where(.dark, .dark *));` to your Tailwind CSS.
- On narrow screens the toolbar stacks and the table scrolls sideways inside its own box.

#### CSV export columns

The export contains the columns the user sees, in the order they see them; action columns are never exported. Pin it down per table:

```ruby
export_columns :name, :email, :created_at   # default list, and the only columns that can be exported
column :internal_note, exportable: false    # never exported
```

#### Large tables

```ruby
# Skip SELECT COUNT(*): only previous/next, no total or page numbers
countless
```

#### Batch actions

Row checkboxes plus an action bar. The gem renders them and sends the selected ids as `ids[]` to your endpoints:

```ruby
batch_actions do
  action :feature, label: "Feature", url: "/posts/batch", method: :patch, color: :primary
  action :delete,  label: "Delete",  url: "/posts/batch", method: :delete, color: :danger,
                   confirm: "Delete %{count} posts?"
end

# Checkboxes only (read the selection from your own JavaScript)
checkbox_column
```

`color:` is one of `:default`, `:primary`, `:success`, `:warning`, `:danger`; `method:` is one of `:get`, `:post`, `:put`, `:patch`, `:delete`.

#### Table Height

```ruby
# Override global height settings for this table
table_min_height "500px"
table_max_height "700px"

# Or size the table to the window: it grows until its bottom (with the pagination) sits
# 16px above the bottom of the viewport, and follows window resizes. table_min_height is the floor.
table_height :fill
table_height :fill, offset: 32   # keep 32px free below
```

#### Infinite Scroll

```ruby
# Enable infinite scroll (replaces pagination)
infinite_scroll true
```

#### Row Links

Make entire rows clickable:

```ruby
# Dynamic URL based on record
row_link ->(record) { "/users/#{record.id}" }

# Static URL
row_link "/users/show"
```

Features:
- Click row to navigate
- Cmd/Ctrl+Click to open in new tab
- Ignores clicks on buttons, links, and inputs

#### Row click, classes and data attributes

```ruby
# Style rows by their data (write the Tailwind classes out in full so they are generated)
row_class ->(order) { "bg-red-50" if order.overdue? }

# data-* attributes on the <tr>, e.g. for your own Stimulus controller
row_data ->(post) { { post_id: post.id, status: post.status } }   # data-post-id, data-status

# Rows fire a cancelable `infotable:row-click` event (needs no row_link)
row_click
```

Every row also gets `id="<dom_id>"` (`order_42`), so Turbo Streams can target it (`turbo_stream.replace dom_id(order)`, `broadcasts_to`). Rows without a record id are left without one.

Clicking a row (not a link, button or input inside it) first dispatches `infotable:row-click` on the `<tr>`, with `detail: { id, url, data, originalEvent }`. If nothing calls `preventDefault()` and the table has a `row_link`, the click then falls back to following it, so the two compose:

```js
document.addEventListener("infotable:row-click", event => {
  if (event.detail.data.status === "locked") event.preventDefault()   // no navigation for locked rows
  else openPreview(event.detail.data.postId)                          // ...or handle it yourself
})
```

#### Row Size

Control table row padding and text size with three options:

```ruby
# Slim - Compact padding (px-2 py-1) with smaller text
row_size :slim

# Mid - Medium padding (px-4 py-2.5) - default text size
row_size :mid

# Default - Full padding (px-6 py-4) with normal text (default)
row_size :default
```

**Backward compatibility:** The old `slim_rows true` method still works and maps to `row_size :slim`

**Visual comparison:**
- **Slim**: Minimal padding, smaller text - ideal for dense data tables
- **Mid**: Moderate padding, normal text - balanced appearance
- **Default**: Generous padding, normal text - comfortable reading

#### Toolbar

```ruby
toolbar :rail   # :header (default) or :rail
```

`:rail` hides the header bar and puts filters (with a badge of active filters), columns, CSV export and refresh on a slim vertical rail at the table's right edge. Search moves to the top of the drawer.

#### Filters Button Visibility

Show or hide the filters button:

```ruby
show_filters_button false  # Hide filters button
```

---

## Formatters

Formatters customize how values are displayed.

### Built-in Formatters

#### 1. Date Formatter (`:date`)

```ruby
column :created_at,
  type: :datetime,
  formatter: :date,
  formatter_options: { format: :short }  # :short, :long, :datetime
```

#### 2. Currency Formatter (`:currency`)

```ruby
column :price,
  type: :decimal,
  formatter: :currency,
  formatter_options: { precision: 2 }
```

#### 3. Boolean Formatter (`:boolean`)

```ruby
column :active,
  type: :boolean,
  formatter: :boolean
```

Displays checkmark (✓) for true, X (✗) for false.

#### 4. Badge Formatter (`:badge`)

```ruby
column :status,
  type: :badge,
  formatter: :badge,
  formatter_options: {
    colors: {
      "active" => "green",
      "inactive" => "gray",
      "pending" => "yellow"
    }
  }
```

Available colors: `green`, `red`, `yellow`, `blue`, `indigo`, `purple`, `pink`, `gray`, `cyan`

#### 5. Action Formatter (`:action`)

```ruby
column :actions,
  type: :action,
  formatter: :action,
  formatter_options: {
    actions: [
      {
        label: "View",
        url: ->(record) { "/users/#{record.id}" },
        color: "primary"  # primary, secondary, danger
      },
      {
        label: "Delete",
        url: ->(record) { "/users/#{record.id}" },
        method: :delete,
        color: "danger",
        confirm: "Are you sure?"
      }
    ],
    style: :buttons  # :buttons (default), :links or :dropdown (a keyboard-friendly menu, no JavaScript)
  }
```

`method:` and `confirm:` use Turbo (`data-turbo-method`, `data-turbo-confirm`). Labels are HTML-escaped.

#### 6. Link Formatter (`:link`)

```ruby
column :website, formatter: :link, formatter_options: { external: true }   # the value is the URL

column :email,
  formatter: :link,
  formatter_options: { url: ->(record) { "mailto:#{record.email}" } }       # email / phone: mailto: and tel:

column :name,
  formatter: :link,
  formatter_options: { url: ->(record) { user_path(record) } }              # Proc (run in the view), Symbol or String
```

Only relative URLs, `http(s)`, `mailto` and `tel` are linked (`javascript:` and friends render as plain text). Options: `url`, `label`, `external` (`target="_blank"` + `rel="noopener noreferrer"`), `class`.

#### 7. Avatar Formatter (`:avatar`)

```ruby
column :avatar_url,
  formatter: :avatar,
  formatter_options: { name: ->(record) { record.name }, size: :md }   # :sm, :md, :lg
```

The value is the image URL; without one, the initials of `name` are shown on a coloured disc. `label: false` hides the name next to the picture.

#### 8. Percent Formatter (`:percent`)

```ruby
column :completion, formatter: :percent, formatter_options: { precision: 1, bar: true }
```

Options: `precision` (default 0), `scale: :percent` (0-100, default) or `:ratio` (0-1), `bar` (small progress bar).

#### 9. Number Formatter (`:number`)

```ruby
column :views_count, formatter: :number, formatter_options: { compact: true }          # 1.5k, 3.4M
column :latency,     formatter: :number, formatter_options: { unit: "ms", precision: 1 }
column :stock,       formatter: :number, formatter_options: { zero: "-" }
```

Options: `precision`, `delimiter` (`","`), `separator` (`"."`), `unit` (appended), `compact`, `zero` (shown instead of 0).

#### 10. Tags Formatter (`:tags`, alias `:list`)

```ruby
column :roles,
  formatter: :tags,
  formatter_options: { limit: 3, colors: { "admin" => "red" } }

# several values in a cell that is not an attribute: use `value:`
column :labels, value: ->(post) { post.tags.map(&:name) }, formatter: :tags, formatter_options: { limit: 2 }
```

The value is an Array, a relation or a comma separated string; each item is a small badge. `limit` shows N items and "+M" (the rest is in its tooltip), `label: ->(item) { item.name }` picks the text, `colors` maps item to badge colour (as in `:badge`), `separator: ", "` renders plain text instead of badges. The CSV export joins the items with `", "`.

#### 11. Truncate Formatter (`:truncate`)

```ruby
column :description, formatter: :truncate, formatter_options: { length: 80 }
```

Long text is cut to `length` (default 60, `omission` default `"…"`); the full text is in the cell's tooltip.

#### 12. Image Formatter (`:image`)

```ruby
column :photo_url,
  formatter: :image,
  formatter_options: { size: :md, alt: ->(record) { record.name }, link: true }   # :sm (32px), :md (48px), :lg (64px)
```

A square thumbnail (use `:avatar` for round pictures). Only http(s) and relative URLs are rendered. `link: true` opens the full image in a new tab.

#### 13. Filesize Formatter (`:filesize`)

```ruby
column :byte_size, formatter: :filesize        # 1536 => "1.5 KB"
```

`precision` is the number of significant digits (default 2).

#### 14. Duration Formatter (`:duration`)

```ruby
column :duration_seconds, formatter: :duration                                        # 3900 => "1h 05m"
column :duration_seconds, formatter: :duration, formatter_options: { format: :long }  # "1 hour 5 minutes"
```

The value is in seconds. `parts` limits how many units are shown (default 2). Translated through `infotable.formatters.duration` (Polish plural forms work out of the box).

The Date formatter's `format: :relative` keeps the exact time in a tooltip, and the Currency formatter takes `unit`, `precision`, `delimiter` and `separator` from your locale (`number.currency.format`) for whatever you do not pass.

### Custom Formatters

#### Lambda/Proc Formatter

```ruby
column :name,
  formatter: ->(value, record) { content_tag(:strong, value) }
```

The lambda receives:
- `value` - Column value
- `record` - Full record object

The returned string is rendered as-is when you mark it `html_safe`, so escape anything that comes from user data: `safe_join(["<strong>".html_safe, value, "</strong>".html_safe])` or `content_tag(:strong, value)`.

#### Hash Formatter

```ruby
column :status,
  formatter: {
    type: :badge,
    options: { colors: { "active" => "green" } }
  }
```

---

## Filters

### Filter Types

Filters are automatically enabled for columns with `filterable: true`.

#### Text Filter (`:text`)

```ruby
column :name,
  filterable: true,
  filter_type: :text
```

Operators: Contains, Starts with, Ends with, Equals, Does not contain

#### Number Filter (`:number`)

```ruby
column :age,
  filterable: true,
  filter_type: :number
```

Operators: Equals, Greater than, Less than, Greater or equal, Less or equal, Between

#### Date Filter (`:date`)

```ruby
column :created_at,
  filterable: true,
  filter_type: :date
```

Operators: On, Before, After, Between

#### Select Filter (`:select`)

```ruby
column :status,
  filterable: true,
  filter_type: :select,
  filter_options: ["active", "inactive", "pending"]

# Or with dynamic options (Proc)
column :company,
  filterable: true,
  filter_type: :select,
  filter_options: -> { Company.pluck(:name) }

# Or with custom label/value pairs
column :status,
  filterable: true,
  filter_type: :select,
  filter_options: [["Active", "active"], ["Inactive", "inactive"]]
```

#### Boolean Filter (`:boolean`)

```ruby
column :active,
  filterable: true,
  filter_type: :boolean
```

Options: True, False, Any

### Auto-apply Filters

Control filter application behavior:

```ruby
# Global (in initializer)
config.autofilter = true  # Apply filters automatically (debounced)
config.autofilter = false # Require "Apply Filters" button click

# Per-table (in view)
<%= infotable :users_table, autofilter: false %>
```

---

## View Helpers

### Basic Usage

```ruby
<%= infotable :users_table %>
```

### Available Options

```ruby
<%= infotable :users_table,
    title: "Active Users",
    subtitle: "Currently logged in users",
    autofilter: false,
    per_page: 50,
    per_page_options: [25, 50, 100],
    drawer_position: :left,
    drawer_width: "500px",
    theme: :default
%>
```

| Option | Type | Description |
|--------|------|-------------|
| `title` | String | Table title (defaults to table class name) |
| `subtitle` | String | Optional subtitle (not shown if nil) |
| `autofilter` | Boolean | Override global autofilter setting |
| `per_page` | Integer | Override default per page |
| `per_page_options` | Array | Override per page options |
| `drawer_position` | Symbol | Override drawer position |
| `drawer_width` | String | Override drawer width |
| `theme` | Symbol | Override theme |

---

## Internationalization (i18n)

InfoTable includes English, Polish, German, French, Spanish, Greek and Italian translations. Any key can be overridden in your app.

### Set Locale

```ruby
# config/application.rb
config.i18n.default_locale = :en
config.i18n.available_locales = [:en, :pl]

# Or per-request
class ApplicationController < ActionController::Base
  before_action :set_locale

  def set_locale
    I18n.locale = params[:locale] || I18n.default_locale
  end
end
```

### Available Languages

- English (`:en`) - Default
- Polish (`:pl`), German (`:de`), French (`:fr`), Spanish (`:es`), Greek (`:el`), Italian (`:it`)

### Customize Translations

Override translations in your app:

```yaml
# config/locales/infotable.en.yml
en:
  infotable:
    table:
      buttons:
        export_csv: "Download CSV"
```

### Add Another Language

```yaml
# config/locales/infotable.pt.yml
pt:
  infotable:
    table:
      buttons:
        export_csv: "Exportar CSV"
        filters: "Filtros"
      # ... see config/locales/en.yml for full structure
```

See [docs/i18n.md](docs/i18n.md) for complete translation documentation.

---

## Advanced Features

### Column Visibility & Ordering

Users can:
- Show/hide columns
- Drag to reorder columns
- Pin columns to left or right
- Reset to defaults

Changes persist in localStorage per table.

### Pinned Columns

Pin columns by default:

```ruby
column :id, pinned: :left   # Pin to left
column :actions, pinned: :right  # Pin to right
```

Users can also pin/unpin columns via the UI.

### Sticky Header

Table headers remain visible while scrolling through table content.

### Export to CSV

Built-in CSV export with:
- Current filters applied
- Current sort order
- Only visible columns
- All pages (not just current)

---

## MCP Server (AI assistants)

The gem ships an [MCP](https://modelcontextprotocol.io) server, so an AI assistant (Claude Code, Cursor, ...) can create tables in your app: it reads your models, asks you how the table should look, generates `app/infotable/*_table.rb` and checks that it works. It talks to your app over stdio on your machine, no port is opened.

Add the `mcp` gem to the app (it is not a dependency of infotable):

```ruby
# Gemfile
gem "mcp", group: :development
```

Register the server in the client, from the app's root. For Claude Code:

```bash
claude mcp add infotable -- bundle exec infotable-mcp
```

or commit a `.mcp.json` (Cursor: `.cursor/mcp.json`):

```json
{
  "mcpServers": {
    "infotable": { "command": "bundle", "args": ["exec", "infotable-mcp"] }
  }
}
```

Then ask: *"create an InfoTable table for Order"*. Or use the `new_table` prompt, which makes the assistant ask for the settings first.

| Tool | What it does |
|------|--------------|
| `list_models` | Models with column types, enums and associations |
| `list_tables` | Tables that already exist, with their settings (the house style) |
| `describe_dsl` | Column options, types, filters, formatters and settings of the installed version |
| `table_options` | Questions about a new table (columns, sort, per page, toolbar, selection, authorization...) with defaults proposed from the model |
| `generate_table` | Renders the table with the `infotable:table` generator. Only shows the code; `write: true` saves it, an existing file is replaced only with `overwrite: true` |
| `validate_table` | Loads a table by name or from source and reports missing columns, a bad `default_sort`, a failing query or a missing `authorize`; `preview: 5` returns the first rows |

The full README is available to the assistant as the `infotable://readme` resource.

Notes: the server boots your app (development environment unless `RAILS_ENV` is set) and reads the development database; it writes only to `app/infotable/`. Tables are generated without `authorize` unless you give one, and `validate_table` warns about that (see [Security](#security)).

## Examples

### Basic Table

```ruby
class UsersTable < Infotable::Base
  query { User.all }

  column :id, sortable: true
  column :name, sortable: true, searchable: true
  column :email, sortable: true
  column :created_at, type: :datetime, sortable: true

  per_page 25
  default_sort :created_at, :desc
end
```

### Table with Filters

```ruby
class ProductsTable < Infotable::Base
  query { Product.all }

  column :name,
    sortable: true,
    filterable: true,
    filter_type: :text

  column :category,
    sortable: true,
    filterable: true,
    filter_type: :select,
    filter_options: -> { Product.distinct.pluck(:category) }

  column :price,
    type: :decimal,
    sortable: true,
    filterable: true,
    filter_type: :number,
    formatter: :currency

  column :in_stock,
    type: :boolean,
    filterable: true,
    formatter: :boolean

  per_page 25
end
```

### Table with Custom Formatters

```ruby
class OrdersTable < Infotable::Base
  query { Order.includes(:customer) }

  column :order_number,
    formatter: ->(value, record) {
      "<code class='font-mono'>#{value}</code>".html_safe
    }

  column :customer,
    formatter: ->(value, record) { record.customer.name }

  column :status,
    type: :badge,
    formatter: :badge,
    formatter_options: {
      colors: {
        "pending" => "yellow",
        "processing" => "blue",
        "shipped" => "green",
        "delivered" => "green",
        "cancelled" => "red"
      }
    }

  column :total,
    type: :currency,
    formatter: :currency,
    formatter_options: { precision: 2 }

  column :actions,
    type: :action,
    formatter: :action,
    formatter_options: {
      actions: [
        { label: "View", url: ->(r) { "/orders/#{r.id}" } },
        { label: "Invoice", url: ->(r) { "/orders/#{r.id}/invoice" } }
      ]
    }
end
```

### Infinite Scroll Table

```ruby
class PostsTable < Infotable::Base
  query { Post.published.includes(:author) }

  column :title, sortable: true
  column :author, sortable: true
  column :published_at, type: :datetime, sortable: true

  infinite_scroll true
  per_page 50
  default_sort :published_at, :desc
end
```

### Clickable Rows Table

```ruby
class CommentsTable < Infotable::Base
  query { Comment.includes(:post) }

  column :body, type: :text
  column :author_name
  column :created_at, type: :datetime

  # Make rows clickable
  row_link ->(record) { "/comments/#{record.id}" }

  # Use slim rows for compact display
  row_size :slim
end
```

### Table with Pinned Columns

```ruby
class SalesTable < Infotable::Base
  query { Sale.all }

  column :id, pinned: :left, width: "60px"
  column :product_name
  column :quantity
  column :price, type: :currency
  column :total, type: :currency
  column :actions, pinned: :right, type: :action
end
```

### Tables with Different Row Sizes

```ruby
# Slim - Compact for dense data
class CompactDataTable < Infotable::Base
  query { Data.all }

  column :id
  column :name
  column :value

  row_size :slim # Minimal padding, smaller text
end

# Mid - Balanced appearance
class BalancedTable < Infotable::Base
  query { Product.all }

  column :id
  column :name
  column :price, type: :currency

  row_size :mid # Medium padding, normal text
end

# Default - Comfortable reading
class ReadableTable < Infotable::Base
  query { Article.all }

  column :title
  column :author
  column :published_at, type: :datetime

  row_size :default # Full padding (or omit - it's the default)
end
```

### Table with Virtual (Aggregated) Columns

```ruby
class ShopsTable < Infotable::Base
  # Query with aggregated columns
  query do
    Shop.select(
      "shops.*",
      "COUNT(products.id) AS products_count",
      "COUNT(accessories.id) AS accessories_count",
      "SUM(products.price) AS total_products_value"
    )
      .left_joins(:products, :accessories)
      .group("shops.id")
  end

  # Regular columns - use WHERE for filtering
  column :id, sortable: true
  column :name, sortable: true, filterable: true, filter_type: :text
  column :active, type: :boolean, sortable: true, filterable: true

  # Virtual columns - use HAVING for filtering
  column :products_count,
    label: "Products",
    type: :integer,
    sortable: true,
    filterable: true,
    filter_type: :number,
    virtual: true,  # ⭐ Enables HAVING clause for filters
    virtual_sql: "COUNT(products.id)"  # SQL expression for filtering

  column :accessories_count,
    label: "Accessories",
    type: :integer,
    sortable: true,
    filterable: true,
    filter_type: :number,
    virtual: true,  # ⭐ Enables HAVING clause for filters
    virtual_sql: "COUNT(accessories.id)"  # SQL expression for filtering

  column :total_products_value,
    label: "Total Value",
    type: :decimal,
    sortable: true,
    filterable: true,
    filter_type: :number,
    virtual: true,  # ⭐ Enables HAVING clause for filters
    virtual_sql: "SUM(products.price)",  # SQL expression for filtering
    formatter: :currency

  per_page 25
end
```

**See [docs/virtual_columns.md](docs/virtual_columns.md) for more examples and detailed explanation.**

---

## Roadmap

- [ ] Server-side persistence of column settings

---

## Documentation

- [Installation Guide](docs/installation.md) - Detailed setup for all bundlers
- [Tailwind setup](docs/tailwind.md)
- [Bundler support](docs/bundlers.md)
- [Virtual columns](docs/virtual_columns.md)
- [i18n Guide](docs/i18n.md)
- [Changelog](CHANGELOG.md)

---

## Running the demo (dummy) app

The repo has a Rails app in `test/dummy` that uses the gem from the working tree, with sample tables for users, products, authors, posts and comments (`test/dummy/app/infotable/`). Use it to try a change by hand:

```bash
git clone https://github.com/jcieslar/infotable.git && cd infotable
bundle install
bin/rails app:db:create app:db:schema:load app:db:seed   # PostgreSQL; add DB=sqlite3 to every command for SQLite
bin/rails app:tailwindcss:build                          # CSS of the dummy app
cd test/dummy && bin/rails server                        # http://localhost:3000
```

The seeds do not create products: run `bin/rails app:db:seed_products` (100k+ rows, good for trying big tables) before opening `/products`.

Open `/` for the list of demo tables (`/users`, `/products`, `/authors`, `/posts`, `/comments`). Another port: `bin/rails server -p 3001`.

While you work on views or JavaScript, `cd test/dummy && bin/dev` runs the server together with `tailwindcss:watch` (it needs the `foreman` gem, `bin/dev` installs it). Restart the server after changing Ruby code of the gem.

If the page is blank or unstyled, rebuild the CSS (`bin/rails app:tailwindcss:build`); if it errors on the database, run `bin/rails app:db:prepare` (SQLite: `DB=sqlite3`).

To try the MCP server on the demo tables: `cd test/dummy && bundle exec infotable-mcp` (see [MCP Server](#mcp-server-ai-assistants)).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/jcieslar/infotable. See [CONTRIBUTING.md](CONTRIBUTING.md) for the setup and the checks a change has to pass, and [SECURITY.md](SECURITY.md) for reporting vulnerabilities.

---

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
