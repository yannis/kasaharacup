# frozen_string_literal: true

require "rails_helper"

describe "Admin bracket encounter panel", :js do
  let(:cup) { create(:cup) }
  let(:category) { create(:team_category, cup: cup, pool_size: nil) }
  let(:admin) { create(:user, :admin) }

  before do
    create_list(:team, 4, team_category: category)
    TeamCategoryBracketBuilder.new(category, random: Random.new(1)).call
  end

  def panel_selector
    "turbo-frame#encounter_panel_team_category_#{category.id}"
  end

  it "opens the editor below the tree, closes it, and reopens another encounter" do
    signin_and_visit(admin, admin_team_category_path(category))

    click_link "Encounter 1"

    within(panel_selector) { expect(page).to have_button("Close") }
    # The bracket tree is still on the page, above the editor.
    expect(page).to have_css(".competition-tree")

    click_button "Close"
    expect(page).to have_no_button("Close")
    expect(page).to have_css(".competition-tree")

    # Re-clicking the SAME encounter must reload the panel — this is what the
    # controller's src-clearing guards against (a surviving src would make
    # Turbo treat the navigation as a no-op and leave the panel empty).
    click_link "Encounter 1"
    within(panel_selector) { expect(page).to have_button("Close") }

    # Clicking another card swaps its editor into the same (already open)
    # panel — assert encounter-2 content, since the Close button alone would
    # still be there from the encounter-1 editor.
    second = category.bracket_encounters.where(round: 1).order(:position).second
    click_link "Encounter 2"
    within(panel_selector) { expect(page).to have_text(second.team_1.name) }
  end
end
