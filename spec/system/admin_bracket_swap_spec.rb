# frozen_string_literal: true

require "rails_helper"

describe "Admin bracket drag-to-swap", :js do
  let(:cup) { create(:cup) }
  let(:category) { create(:team_category, cup: cup, pool_size: nil, team_size: 3) }
  let(:admin) { create(:user, :admin) }

  def stock(team, count = 3)
    create_list(:kenshi, count, cup: cup).each do |k|
      create(:participation, category: category, team: team, kenshi: k)
    end
  end

  def build_bracket(team_count = 4)
    create_list(:team, team_count, team_category: category).each { |team| stock(team) }
    TeamCategoryBracketBuilder.new(category, random: Random.new(1)).call
    category.bracket_encounters.where(round: 1).order(:position).to_a
  end

  def slot_selector(encounter, slot)
    "[data-encounter-id='#{encounter.id}'][data-slot='#{slot}']"
  end

  it "swaps two round-1 teams by dragging one slot onto another" do
    first, second = build_bracket
    moving_out = first.team_1
    moving_in = second.team_1

    signin_and_visit(admin, admin_team_category_path(category))

    find("#{slot_selector(first, 1)} .competition-tree__grip")
      .drag_to(find(slot_selector(second, 1)), html5: true)

    # The response carries the redrawn tree, so wait on the rendered name.
    within(slot_selector(second, 1)) { expect(page).to have_content moving_out.name }
    expect(first.reload.team_1).to eq moving_in
    expect(second.reload.team_1).to eq moving_out
  end

  it "offers no grip on an encounter that already has a result" do
    first, = build_bracket
    first.update!(winner: first.team_1)

    signin_and_visit(admin, admin_team_category_path(category))

    expect(page).to have_no_css("#{slot_selector(first, 1)} .competition-tree__grip")
  end

  it "keeps a slot swappable after its panel has auto-seeded both lineups" do
    first, = build_bracket
    signin_and_visit(admin, admin_team_category_path(category))

    find("a[href='#{admin_team_category_encounter_path(category, first)}']").click
    expect(page).to have_css(".encounter__close-panel")
    # Wait for the seed POST to land before asserting on it.
    expect(page).to have_css(".pool-match__grip", minimum: 2)

    # Regression: auto-seeding CONFIRMS both lineups, which used to make the
    # encounter non-pristine and silently withdraw its swap controls.
    expect(first.reload.lineup_1_set?).to be true
    expect(page).to have_css("#{slot_selector(first, 1)} .competition-tree__grip")
  end

  it "swaps from the encounter panel's select form without a mouse" do
    first, second = build_bracket
    moving_in = second.team_1

    signin_and_visit(admin, admin_team_category_path(category))
    find("a[href='#{admin_team_category_encounter_path(category, first)}']").click

    within(".swap-team__form--slot_1") do
      select moving_in.name, from: "team_id_1"
      click_button "Swap"
    end

    # The form posts with data-turbo="false", so this is a full page load and
    # click_button returns before it lands. Wait on the redrawn tree, or the DB
    # assertion races the request.
    within(slot_selector(first, 1)) { expect(page).to have_content moving_in.name }
    expect(first.reload.team_1).to eq moving_in
  end
end
