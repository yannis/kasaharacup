# frozen_string_literal: true

require "rails_helper"

# The desktop navigation row is a no-wrap flex row carrying five links, the
# archive dropdown, the locale dropdown and the account cluster — plus live
# kenshi and team counts that grow with entries. Measured, it no longer fits
# below 1024px, which is why the desktop breakpoint is `lg:` and not `sm:`.
# French labels are the longest, so they are what these checks use.
describe "Navigation width", :fr, :js do
  let(:cup) { create(:cup, start_on: Date.current + 1.month) }
  let(:category) { create(:individual_category, cup: cup) }

  before do
    # Realistic counts: the label reads "Inscrits (12)" rather than "Inscrits
    # (0)", so the row is measured at something close to its real width.
    12.times do
      kenshi = create(:kenshi, cup: cup)
      create(:participation, category: category, kenshi: kenshi)
    end
    visit rules_path(locale: :fr)
  end

  def resize(width)
    page.driver.browser.manage.window.resize_to(width, 900)
    # Give the media queries a beat to settle before measuring.
    expect(page).to have_css("nav")
  end

  # A squeezed row does not necessarily overflow horizontally: flex items shrink
  # first and their labels wrap, growing taller than one line. Both symptoms are
  # checked.
  def layout_report
    page.evaluate_script(<<~JS)
      (() => {
        const row = document.querySelector("nav div.relative.flex.items-center");
        const controls = Array.from(row.querySelectorAll("a, button"))
          .filter((el) => el.offsetParent !== null);
        return {
          scrolls: document.documentElement.scrollWidth > document.documentElement.clientWidth,
          tallest: Math.max(...controls.map((el) => Math.round(el.getBoundingClientRect().height)))
        };
      })()
    JS
  end

  [640, 768, 1024, 1280].each do |width|
    it "fits the navigation without wrapping or horizontal scroll at #{width}px" do
      resize(width)
      report = layout_report
      expect(report["scrolls"]).to be false
      expect(report["tallest"]).to be <= 40
    end
  end

  it "serves the hamburger menu, not the desktop row, below 1024px" do
    resize(768)
    expect(page).to have_css("button[aria-controls='mobile-menu']")
    expect(page).to have_no_css("nav a[href='/fr/rules']", visible: :visible)
  end

  it "serves the desktop row, not the hamburger, on a wide viewport" do
    # 1280 rather than exactly 1024: `resize_to` sets the window, and the
    # viewport ends up narrower than that, so 1024 can land just under the `lg`
    # breakpoint.
    resize(1280)
    expect(page).to have_css("nav a[href='/fr/rules']", visible: :visible)
    expect(page).to have_no_css("button[aria-controls='mobile-menu']", visible: :visible)
  end
end
