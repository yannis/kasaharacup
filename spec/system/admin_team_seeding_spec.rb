# frozen_string_literal: true

require "rails_helper"

describe "Admin team category seeding", :js do
  let(:cup) { create(:cup) }
  let(:category) { create(:team_category, cup: cup, pool_size: 3, out_of_pool: 2, team_size: 3) }
  let(:admin) { create(:user, :admin) }

  def team(name, seed: nil)
    create(:team, team_category: category, name: name, seed: seed)
  end

  def seed_order
    category.teams.seeded.map(&:name)
  end

  it "reorders the seeds by dragging one onto the position it should take" do
    team("Aaa", seed: 1)
    team("Bbb", seed: 2)
    team("Ccc", seed: 3)

    signin_and_visit(admin, admin_team_category_path(category))

    third_grip = find(".seed-panel__row[data-position='3'] .seed-panel__grip")
    first_row = find(".seed-panel__row[data-position='1']")
    third_grip.drag_to(first_row, html5: true)

    # Wait for the Turbo Stream to replace the panel with the new numbering.
    expect(page).to have_css(".seed-panel__row[data-position='1']", text: "Ccc")
    expect(seed_order).to eq %w[Ccc Aaa Bbb]
  end

  it "seeds a team from the add select" do
    team("Aaa", seed: 1)
    team("Ddd")

    signin_and_visit(admin, admin_team_category_path(category))

    find(".seed-panel__add-select").select("Ddd")

    expect(page).to have_css(".seed-panel__row[data-position='2']", text: "Ddd")
    expect(seed_order).to eq %w[Aaa Ddd]
  end

  it "unseeds from the ✕ button and closes the gap" do
    team("Aaa", seed: 1)
    team("Bbb", seed: 2)

    signin_and_visit(admin, admin_team_category_path(category))

    within(".seed-panel__row[data-position='1']") { click_button "✕" }

    expect(page).to have_css(".seed-panel__row[data-position='1']", text: "Bbb")
    expect(seed_order).to eq %w[Bbb]
  end

  # A bracket-only category renders no pool cards, so the panel is the only
  # thing on the page holding a Turbo subscription — if it did not subscribe on
  # its own, nothing here would update.
  it "works on a bracket-only category, which has no pool cards" do
    category.update!(pool_size: 1)
    team("Aaa", seed: 1)
    team("Bbb")

    signin_and_visit(admin, admin_team_category_path(category))

    find(".seed-panel__add-select").select("Bbb")

    expect(page).to have_css(".seed-panel__row[data-position='2']", text: "Bbb")
    expect(seed_order).to eq %w[Aaa Bbb]
  end
end
