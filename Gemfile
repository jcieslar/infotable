source "https://rubygems.org"

# Specify your gem's dependencies in infotable.gemspec.
gemspec

# Server
gem "puma"

# Database
gem "pg"
gem "minitest", ">= 5.25"
gem "minitest-mock"

# Assets
gem "propshaft"

# Hotwire stack (for dummy app)
gem "turbo-rails"
gem "stimulus-rails"
gem "importmap-rails"

# Pagination
gem "pagy"

# Styling (for dummy app)
gem "tailwindcss-rails"

# Omakase Ruby styling [https://github.com/rails/rubocop-rails-omakase/]
gem "rubocop-rails-omakase", require: false

# Start debugger with binding.b [https://github.com/ruby/debug]
# gem "debug", ">= 1.0.0"

# Browser tests (system tests drive headless Chrome through CDP, no chromedriver needed)
group :test do
  gem "capybara", "~> 3.40"
  gem "cuprite", "~> 0.19"
end
