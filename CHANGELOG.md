# Changelog

## Unreleased

### Breaking / behaviour changes
- Requires Ruby >= 3.3 (Pagy 43).
- `query_sql` requires `model:`.
- Requires Pagy 43 (`~> 43.0`); the host app's own Pagy usage must be on 43 too. Pagy is no longer included anywhere except the engine's controller (`Pagy::Method`).
- PostgreSQL is the only supported database.
- Unknown formatter names (`formatter: :curency`) now raise `Infotable::Error` instead of rendering `value.to_s`.
- `nil_value` / `empty_value` placeholders now also apply to named formatters (`:currency`, `:date`, `:badge`, ...).
- The default `drawer_width` is `"26rem"` (what the drawer always used); `drawer_position` and `drawer_width` now take effect.
- `theme`, `turbo_enabled` and `pagination_gem` configuration options remain accepted but have no effect.
- Pagy is no longer included into every host controller and view.
- Actions with `method:` use `data-turbo-method` / `data-turbo-confirm` (they relied on rails-ujs before).

### Added
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
