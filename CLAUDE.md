# InfoTable

Rails engine gem (datatable on Hotwire + Tailwind v4). PostgreSQL and SQLite are supported.

## Demo app

The live demo is a separate Rails app in `~/code/infotable_page` (https://infotable.infovation.eu/). When we add a new feature to the gem, we also want to show it there: add it to one of the demo's tables in `app/infotable/` (or a new one), once the new gem version is published and the demo is on it (`bundle update infotable`). The demo depends on the released gem from rubygems.org, not on a local path.

## Workflow

- Tests: `bin/rails test` (PostgreSQL) and `DB=sqlite3 bin/rails test`; `bin/rubocop` must be clean.
- A feature changes `CHANGELOG.md` (and the README when it is user-facing); a release bumps `lib/infotable/version.rb` and `package.json`.
