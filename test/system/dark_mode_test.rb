require "application_system_test_case"

class DarkModeTest < ApplicationSystemTestCase
  setup { create_users }

  def emulate(scheme)
    page.driver.browser.page.command("Emulation.setEmulatedMedia", features: [ { name: "prefers-color-scheme", value: scheme } ])
  end

  # Perceived brightness (0-255) of a CSS color property on the first element matching the selector.
  # Computed colors can be oklch(), so let a canvas turn them into RGB.
  def brightness(selector, property)
    r, g, b = page.evaluate_script(<<~JS)
      (function () {
        var value = getComputedStyle(document.querySelector(#{selector.to_json}))[#{property.to_json}]
        var context = document.createElement("canvas").getContext("2d")
        context.fillStyle = value
        context.fillRect(0, 0, 1, 1)
        return Array.from(context.getImageData(0, 0, 1, 1).data).slice(0, 3)
      })()
    JS
    (0.299 * r) + (0.587 * g) + (0.114 * b)
  end

  # Colors transition (transition-all), so poll until they settle instead of reading mid-animation
  def assert_brightness(selector, property, operator, limit)
    value = nil
    page.document.synchronize(5) do
      value = brightness(selector, property)
      raise Capybara::ExpectationNotMet, "#{selector} #{property} brightness #{value.round(1)} is not #{operator} #{limit}" unless value.public_send(operator, limit)
    end
  end

  def open_users
    visit "/users"
    wait_for_table("users_table")
  end

  test "light scheme keeps a white table with dark text" do
    emulate("light")
    open_users

    assert_brightness("[data-controller~='infotable--table'] > div", "backgroundColor", :>, 240)
    assert_brightness("turbo-frame#users_table_content tbody td", "color", :<, 100)
  end

  test "dark scheme gives a dark table with light text" do
    emulate("dark")
    open_users

    assert_brightness("[data-controller~='infotable--table'] > div", "backgroundColor", :<, 60)
    assert_brightness("turbo-frame#users_table_content tbody td", "color", :>, 150)
    assert_brightness("turbo-frame#users_table_content thead th", "backgroundColor", :<, 80)
  end

  test "dark scheme darkens the drawer and its inputs" do
    emulate("dark")
    open_users
    find("button[data-action*='infotable--drawer#open']").click

    assert_selector "[role=dialog]:not([aria-hidden='true'])"
    assert_brightness("[role=dialog]", "backgroundColor", :<, 60)
    assert_brightness("[role=dialog] input[name='filters[name][value]']", "backgroundColor", :<, 60)
    assert_brightness("[role=dialog] input[name='filters[name][value]']", "color", :>, 150)
  end

  test "dark scheme keeps status badges readable" do
    emulate("dark")
    open_users

    badge = "turbo-frame#users_table_content tbody span.rounded-full"
    assert_selector badge, minimum: 1
    assert_brightness(badge, "color", :>, 120)
    assert_brightness(badge, "backgroundColor", :<, 80)
  end
end
