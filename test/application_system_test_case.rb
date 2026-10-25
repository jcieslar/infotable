require "test_helper"
require "capybara/rails"
require "capybara/cuprite"
require "capybara/minitest"

Capybara.register_driver(:infotable_cuprite) do |app|
  Capybara::Cuprite::Driver.new(
    app,
    window_size: [ 1400, 1000 ],
    browser_options: { "no-sandbox": nil },
    process_timeout: 20,
    timeout: 15,
    # sortablejs is pinned from a CDN; let it through, block anything else external
    url_blacklist: [],
    js_errors: true
  )
end

Capybara.server = :puma, { Silent: true }
Capybara.default_max_wait_time = 5

class ApplicationSystemTestCase < ActiveSupport::TestCase
  include Capybara::DSL
  include Capybara::Minitest::Assertions

  setup do
    Capybara.current_driver = :infotable_cuprite
    Capybara.app = Rails.application
  end

  teardown do
    Capybara.reset_sessions!
    Capybara.use_default_driver
  end

  # Waits until the table's turbo frame has loaded rows
  def wait_for_table(name)
    assert_selector "turbo-frame##{name}_content table tbody tr", wait: 10
  end

  def table_rows(name)
    all("turbo-frame##{name}_content table tbody tr").size
  end
end
