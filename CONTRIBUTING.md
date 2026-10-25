# Contributing

Thanks for helping with InfoTable. Bug reports, fixes, docs and small features are all welcome.

## Before you start

- Search the [issues](https://github.com/jcieslar/infotable/issues) first.
- For anything bigger than a fix (new column option, new formatter, new filter type), open an issue and describe the use case before writing code. It saves you from building something that does not fit.
- Security problems do not go in public issues, see [SECURITY.md](SECURITY.md).

## Setup

You need Ruby 3.3+ and PostgreSQL (SQLite works too).

```bash
git clone https://github.com/jcieslar/infotable.git
cd infotable
bundle install
bin/rails app:db:create app:db:schema:load
bin/rails app:tailwindcss:build      # CSS for the dummy app
```

Run the dummy app to try a change by hand:

```bash
cd test/dummy && bin/rails server
```

## Checks

A change is ready when all of these pass:

```bash
bin/rails test                  # unit and integration tests
bin/rails test:system           # browser tests (headless Chrome, needs Chrome installed)
DB=sqlite3 bin/rails test       # same suite on SQLite
bundle exec rubocop
```

If you touch views or JavaScript, run the system tests and rebuild the dummy app's CSS (`bin/rails app:tailwindcss:build`); the built file in `test/dummy/app/assets/builds/tailwind.css` is committed.

## Pull requests

- One topic per pull request. Several small commits are fine.
- Add or update tests. A bug fix starts with a test that fails without the fix.
- Add a line to `CHANGELOG.md` under "Unreleased" for anything a user would notice.
- Update `README.md` or `docs/` when you change the public API.
- Commit messages use a type prefix: `feat`, `fix`, `docs`, `test`, `refactor`, `chore`.
- Keep to the style of the surrounding code. RuboCop is the referee.

## Design rules

- Styling is Tailwind utility classes only, no custom CSS. Write class names out in full (no string-built class names), or Tailwind will not find them.
- Everything user-visible goes through I18n (`en` and `pl` both).
- User input never reaches SQL unescaped. New filters and operators need a test in the injection fuzz suite.
- Behaviour shown in the browser needs a system test, not only an HTML assertion.

## Code of conduct

By taking part you agree to follow the [Code of Conduct](CODE_OF_CONDUCT.md).
