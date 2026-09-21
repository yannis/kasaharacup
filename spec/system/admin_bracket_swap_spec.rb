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
    # Wait for the panel's auto-seed to land, so the swap is made against an
    # encounter whose lineups are confirmed — the state that used to prompt.
    expect(page).to have_css(".pool-match__grip", minimum: 2)

    # No confirm: nothing here was ordered by hand, so there is nothing to lose.
    within(".swap-team__form--slot_1") do
      select moving_in.name, from: "team_id_1"
      click_button "Swap"
    end

    # The form breaks out of the panel frame to the whole page, so this is a
    # full navigation and click_button returns before it lands. Wait on the
    # redrawn tree, or the DB assertion races the request.
    within(slot_selector(first, 1)) { expect(page).to have_content moving_in.name }
    expect(first.reload.team_1).to eq moving_in
  end

  it "prompts from the panel form only for a partner with a hand-entered order" do
    first, second, third = build_bracket(8)
    second.update!(lineup_1_set: true, lineup_1_set_by_admin: true)

    signin_and_visit(admin, admin_team_category_path(category))
    find("a[href='#{admin_team_category_encounter_path(category, first)}']").click
    # Wait for the auto-seed to land before touching the form: it is rendered
    # with the frame, so it is present BEFORE the seed POST completes, and the
    # seed's morph would otherwise arrive mid-interaction.
    expect(page).to have_css(".pool-match__grip", minimum: 2)
    expect(page).to have_css(".swap-team__form--slot_1")

    # The hand-ordered partner names itself and waits for an answer...
    within(".swap-team__form--slot_1") { select second.team_1.name, from: "team_id_1" }
    expect(page).to have_css(
      ".swap-team__form--slot_1[data-turbo-confirm*='encounter #{second.number}']"
    )

    # ...while an untouched one takes the prompt back off the form.
    within(".swap-team__form--slot_1") { select third.team_1.name, from: "team_id_1" }
    expect(page).to have_no_css(".swap-team__form--slot_1[data-turbo-confirm]")

    within(".swap-team__form--slot_1") { select second.team_1.name, from: "team_id_1" }
    accept_confirm { within(".swap-team__form--slot_1") { click_button "Swap" } }

    within(slot_selector(first, 1)) { expect(page).to have_content second.team_1.name }
  end

  # Regression: the swap form is a SIBLING of the panel a lineup edit morphs,
  # and it bakes each option's verdict in at render. Without its own redraw it
  # kept offering the pre-edit answer ("nothing to lose"), so entering a lineup
  # and then swapping — this feature's own flow — submitted force=false, was
  # refused, and dumped the admin out of the panel onto an unanswerable flash.
  it "asks before a swap that clears an order entered in the same open panel" do
    first, second = build_bracket
    moving_in = second.team_1
    spare = create(:kenshi, cup: cup)
    create(:participation, category: category, team: first.team_1, kenshi: spare)
    form_id = "lineup_#{ActionView::RecordIdentifier.dom_id(first)}_team_#{first.team_1_id}"

    signin_and_visit(admin, admin_team_category_path(category))
    find("a[href='#{admin_team_category_encounter_path(category, first)}']").click
    expect(page).to have_css(".pool-match__grip", minimum: 2)

    # Auto-seeded only, so nobody chose this order and no partner costs anything.
    expect(page).to have_no_css(".swap-team__form--slot_1 option[data-confirm-message]")

    # Hand-enter an order in the very same panel: swap position 1 for the
    # fighter the auto-seed left out.
    page.first("select.pool-match__select[form='#{form_id}']")
      .find("option", text: spare.full_name).select_option

    # The redrawn form now prices every option against the order just entered.
    expect(page).to have_css(
      ".swap-team__form--slot_1 option[data-confirm-message*='encounter #{first.number}']"
    )
    expect(first.reload).to be_hand_ordered

    within(".swap-team__form--slot_1") { select moving_in.name, from: "team_id_1" }
    expect(page).to have_css(".swap-team__form--slot_1[data-turbo-confirm]")

    accept_confirm { within(".swap-team__form--slot_1") { click_button "Swap" } }

    within(slot_selector(first, 1)) { expect(page).to have_content moving_in.name }
    expect(first.reload.team_1).to eq moving_in
  end
end
