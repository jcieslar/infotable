require "application_system_test_case"

class MobileLayoutTest < ApplicationSystemTestCase
  setup do
    create_users
    page.driver.resize(390, 800)
    visit "/users"
    wait_for_table("users_table")
  end

  teardown { page.driver.resize(1400, 1000) }

  def inside_viewport?(selector)
    page.evaluate_script(<<~JS)
      (() => {
        const r = document.querySelector(#{selector.to_json}).getBoundingClientRect()
        return r.left >= 0 && r.right <= document.documentElement.clientWidth + 0.5 && r.width > 0
      })()
    JS
  end

  test "the page does not scroll sideways" do
    assert_equal page.evaluate_script("document.documentElement.clientWidth"), page.evaluate_script("document.documentElement.scrollWidth")
  end

  test "search, export and filters stay inside the screen" do
    assert inside_viewport?("input[name='search']")
    assert inside_viewport?("a[href*='/export']")
    assert inside_viewport?("button[data-action*='infotable--drawer#open']")
  end

  test "the wide table scrolls inside its own container" do
    scroll = "turbo-frame#users_table_content > div[class*='overflow-x-auto']"
    assert page.evaluate_script("(() => { const e = document.querySelector(#{scroll.to_json}); return e.scrollWidth > e.clientWidth })()")
  end

  test "the drawer fits the screen and can be used" do
    find("button[data-action*='infotable--drawer#open']").click
    assert_selector "[role=dialog]:not([aria-hidden='true'])"
    sleep 0.5

    assert inside_viewport?("[role=dialog]")
    find("input[name='filters[name][value]']").fill_in with: "Bob"
    assert_selector "turbo-frame#users_table_content tbody tr", count: 1
  end

  test "pagination and chips wrap instead of overflowing" do
    visit "/users?users_table[search]=a&users_table[filters][age][from]=1"
    wait_for_table("users_table")
    assert_selector "[data-active-filters]"
    assert_equal page.evaluate_script("document.documentElement.clientWidth"), page.evaluate_script("document.documentElement.scrollWidth")
    assert inside_viewport?("[data-active-filters]")
  end

  test "desktop keeps the toolbar on one row" do
    page.driver.resize(1400, 1000)
    visit "/users"
    wait_for_table("users_table")
    title = page.evaluate_script("document.querySelector('h2').getBoundingClientRect().top")
    search = page.evaluate_script("document.querySelector(\"input[name='search']\").getBoundingClientRect().top")
    assert_in_delta title, search, 30
  end
end
