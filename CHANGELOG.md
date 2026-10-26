# Changelog

## Unreleased

### Changed
- Pinned columns move to their edge, keeping their order, so several pinned columns sit side by side with no gap; unpinning restores the order.
- Pinned columns: only the innermost pinned column on each side gets an edge (a full-height 1px line) instead of every pinned cell carrying a gradient, so they no longer look like a layer under the table.
- `toolbar :rail`: the open drawer sits flush against the rail (no rounded corners, no heavy shadow), so there is no notch between them.
- Filters form: flat fields separated by hairlines, soft grey inputs with an indigo focus ring, a quiet "Clear all" button.

## 1.5.0

### Added
- `row_class ->(record) { }`, `row_data ->(record) { { key: value } }` (data-* on the `<tr>`) and `id="<dom_id>"` on every row (a base for Turbo Streams).
- `row_click`: rows fire a cancelable `infotable:row-click` event (`detail: { id, url, data, originalEvent }`); without `preventDefault()` the click falls back to the table's `row_link`. Rows are clickable with `row_click` alone, `row_link` keeps working as before.

### Security
- The installer's initializer now sets `config.parent_controller = "ApplicationController"` (it was commented out), and the README has a Security section: with the engine's default parent (`ActionController::Base`) a table without `authorize` is readable and exportable by anyone.

### Fixed
- CSV export no longer prefixes plain numbers (`-5`, `+48123456789`) with `'`; text that could be a formula still is.
- Infinite scroll kept working only until the first sort, search or per-page change.
- A column pinned by default (`pinned: :left`) can be unpinned in the columns drawer, and "reset" restores the default pins instead of unpinning them. Pinning from the drawer no longer paints cells white in dark mode: the drawer asks the table to apply order, visibility and pinning (the duplicated code is gone).
- Clicking an action `:dropdown` in a `row_link` table no longer follows the row link; row links use `Turbo.visit`.
- A subclassed table keeps its parent's `toolbar` and `export_columns`.
- Changing a filter keeps the rows-per-page choice.
- "Select all N matching" stays offered after infinite scroll loads more rows.
- An infinite-scroll request past the last page no longer appends the first page again; the end-of-list marker is translated and themed (`_end_indicator`).
- Text filters on a non-text column (`filter_type: :text` on an integer) no longer fail on PostgreSQL.
- A datetime filter's "from" starts at the beginning of the day in `Time.zone`, like "to" ends it.
- No primary-key tiebreaker is added to grouped queries (it broke `GROUP BY` on another column).
- The columns drawer survives browsers without `localStorage`; the history state no longer needs `crypto.randomUUID` (plain-HTTP origins).
- `BooleanFormatter` `style: :icon` has an accessible name.
- A capped "select all matching" (`max_select_all`) takes the first N rows in the table's sort order instead of arbitrary ones.
- Selecting 500 rows renders the selection once instead of once per row; applying column visibility is a single pass over the cells.

### Changed
- `config.max_select_all` defaults to 4000 (was 10000): every id is sent as `ids[]` and Rack accepts 4096 parameters per request. A GET batch action with thousands of ids can also exceed URL limits; use `post`/`patch`/`delete` for large selections.
- sortablejs is served with the gem (`infotable/vendor/sortable.esm.js`) instead of a jsDelivr CDN pin.
- Unknown `column` options (a typo like `sortble:`) are logged as a warning.
- `TableResolver` memoizes the class names it tries.
- Fresher table look: quieter header (medium weight, grey), flat row hover instead of the lifted row, lighter row dividers.
- Pinned columns show a pushpin in their header, tilted to the side they are pinned to; the pin buttons in the column list use the same icon instead of chevrons.
- Pinned cells no longer use hard-coded white/grey backgrounds with `!important`; they follow dark mode and the row hover.

### Removed
- Unused `build_export_params` helper, `showLoading` / `hideLoading` and the no-op `config.infotable` engine options.
- `package.json` `files` listed a nonexistent `app/assets/stylesheets`; it now ships `app/assets/tailwind`.

## 1.4.1

### Fixed
- Action columns are no longer clipped to their width: it is a minimum now, and the column grows to show all its buttons (a `width: "150px"` column with three buttons used to hide the last ones).

## 1.4.0

### Added
- `table_height :fill` (optionally `offset: 32`): the rows area grows until the table and its pagination end `offset` px above the bottom of the window, and follows window resizes. `table_min_height` is the floor. `:fixed` (default) keeps `table_max_height`.

### Changed
- `toolbar :rail`: the rail slides left to stay visible beside the open drawer; clicking anywhere on it (or its active tab's button) collapses the drawer.
- Filter drawer restyle: grey body with white filter cards, small uppercase labels, correct rounded corners and a softer shadow.

## 1.3.0

### Added
- CSV export follows the user's on-screen column order, never exports action columns, and has `export_columns :a, :b` (default list and pool) and `exportable: false` per column.
- "Select all N matching" in batch actions: new `tables/:name/ids` endpoint, capped by `config.max_select_all` (default 10000); hidden for countless tables.
- Active filter chips above the rows (each removable, "Clear all filters" from two on) and a filtered empty state with a clear button.
- Column widths: drag the handle on a header's right edge (or focus it and press Left/Right, Shift for bigger steps); double-click resets. Widths are remembered per browser; `resizable_columns false` turns it off.
- Mobile layout: the toolbar stacks on narrow screens, the search takes the full width, chips and the batch bar wrap.
- Dark mode (`prefers-color-scheme`; for a `.dark` class add `@custom-variant dark (&:where(.dark, .dark *));` to your Tailwind CSS).

### Changed
- Action columns are never part of a CSV export, even when named in `visible_columns`.

## 1.2.0

### Added
- Number and date filters in the drawer have an operator select: Between (from/to, the default), Equals, Greater than, Before, After, Is empty, ... Single-value operators show one input; the choice is kept in shared links (`url_state`).

## 1.1.0

### Added
- `toolbar :rail`: hides the header bar and puts the controls on a slim vertical rail at the table's right edge: filters (with a badge counting the columns that have an active filter), columns, CSV export and refresh. Global search moves to the top of the drawer. The default stays `toolbar :header`.

## 1.0.1

### Fixed
- Tailwind did not scan the gem's views when the gem was installed outside the app (no styles for the drawer, spinner, ...). The gem now ships `app/assets/tailwind/infotable/engine.css` and the installer adds `@import "../builds/tailwind/infotable";` to the Tailwind entry file. The generated `infotable.css(.erb)`, its Rake task, the `INFOTABLE_*_PATH` env variables and `Infotable.views_path` / `formatters_path` are gone; upgrade steps are in `docs/tailwind.md`.

## 1.0.0

### Breaking / behaviour changes
- Requires Ruby >= 3.3 (Pagy 43).
- `query_sql` requires `model:`.
- Requires Pagy 43 (`~> 43.0`); the host app's own Pagy usage must be on 43 too. Pagy is no longer included anywhere except the engine's controller (`Pagy::Method`).
- PostgreSQL and SQLite are the supported databases (SQLite matches case-insensitively for ASCII only).
- Unknown formatter names (`formatter: :curency`) now raise `Infotable::Error` instead of rendering `value.to_s`.
- `nil_value` / `empty_value` placeholders now also apply to named formatters (`:currency`, `:date`, `:badge`, ...).
- The default `drawer_width` is `"26rem"` (what the drawer always used); `drawer_position` and `drawer_width` now take effect.
- `theme`, `turbo_enabled` and `pagination_gem` configuration options remain accepted but have no effect.
- Pagy is no longer included into every host controller and view.
- Actions with `method:` use `data-turbo-method` / `data-turbo-confirm` (they relied on rails-ujs before).

### Added
- SQLite support: text filters and global search use `LIKE ... ESCAPE` there (`Infotable::Sql`); the suite runs on both databases (`DB=sqlite3 bin/rails test`).
- Browser system tests (Capybara + Cuprite, `bin/rails test:system`) for search, sorting, the filter drawer, per-page/pagination, batch actions and URL state; JavaScript errors fail the test.
- `rails generate infotable:table MODEL [--only=..] [--skip=..]` writes a table definition from the model's columns (enums become select filters, secrets and foreign keys are skipped, `belongs_to` come as hints).
- Formatters `:link` (only http(s), mailto, tel and relative URLs are linked), `:avatar` and `:percent`.
- Select filter options: `filter_options_cache:` caches a Proc's result, `filter_options_limit:` / `config.max_filter_options` (500) cap the `<option>`s and the drawer says when a list was cut.
- Table state in the URL (`?users_table[search]=..&users_table[page]=2`): shareable links, reload keeps the table, Back works. `config.url_state` / `url_state false` per table.
- `aria-current="page"` on the current page number.
- Action column `style: :dropdown` is a real menu (`<details>`), not a list of links.
- Drawer accessibility: `role=dialog`, labelled, `inert` while closed, focus in/out.
- `query_sql "SELECT ...", model: User` now works: the SQL becomes an aliased sub-select, so filters, search, sorting, pagination and export apply (it used to return a bare `ActiveRecord::Result` and could not). `model:` is required.
- Multi-column sorting: `sort=name:asc,age:desc` (Shift+click on headers, max 3, numbered indicators); `sort_column`/`sort_direction` keep working.
- `countless` tables: pagination without `COUNT(*)` (prev/next only).
- Batch actions: `checkbox_column`, `batch_actions { action ... }`, selection bar, `ids[]` sent to your endpoint.
- Global search over `searchable: true` columns.
- `authorize { |controller| ... }` per table (403), `config.parent_controller`, and `query { |controller| ... }`.
- Column option `includes:` preloads associations used by `value:`/formatters (no N+1) for the table and CSV export.
- Column options `sql:`, `sort_sql:` and `value:` for association and computed columns.
- Number filter operators (`eq neq gt gte lt lte between is_empty is_not_empty`) and date operators (`on before after between is_empty is_not_empty`); `from`/`to` ranges keep working.
- `Infotable::TableResolver`: multi-word and namespaced table names (`:order_items_table`, `cms_admins_users_table`).
- en/pl translations for filter operators, placeholders, formatters and the drawer title.
- Dummy-app formatters escape user data (XSS regression test).
- Test suite (minitest, PostgreSQL) and CI with a Postgres service.

### Fixed
- Several tables per page: filter control ids are prefixed with the table name (they collided for tables sharing column names); the text-filter inline `<script>` is gone (works under a strict CSP) and clearing filters finds controls by name inside the table's own form.
- Hostile/random params no longer 500 (select filters cast to column type, NUL bytes, NaN, non-string params, out-of-range values -> 400); covered by a seeded fuzz test.
- No more `ostruct` dependency (removed from default gems in Ruby 3.5; the `_table` partial also failed with `uninitialized constant OpenStruct` when rendered before the helper).
- Filters are kept across sorting, pagination, per-page changes and CSV export.
- Stable pagination: primary key is appended as the last `ORDER BY`.
- CSV export respects sorting, is streamed in batches, guards against formula injection and quotes the filename.
- Invalid `per_page` / `page` / `filters` params no longer return 500; `per_page` is capped at 500.
- Decimal bounds against integer columns in number filters no longer raise.
- Per-page selector uses the table's `per_page_options`.
- `pinned:` defaults apply on first load; `row_link` data attributes are no longer HTML-escaped.
- Subclassed tables inherit their parent's definition; `filter_multi_select` is stored.
- Badge `cyan`, `DateFormatter` with String values, escaped action labels.
- Drawer click-outside listener leak and nested table controller on the per-page select.
