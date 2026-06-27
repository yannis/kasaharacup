# frozen_string_literal: true

require "rails_helper"

describe "Admin team lineup via in-table dropdowns", :js do
  let(:cup) { create(:cup) }
  let(:tc) { create(:team_category, cup: cup, team_size: 3) }
  let(:t1) { create(:team, team_category: tc) }
  let(:t2) { create(:team, team_category: tc) }
  let(:admin) { create(:user, :admin) }

  def member(team)
    create(:kenshi, cup: cup).tap { |k| create(:participation, category: tc, team: team, kenshi: k) }
  end

  it "assigns a fighter straight from the match table and keeps the pick" do
    encounter = create(:encounter, team_category: tc, team_1: t1, team_2: t2)
    fighter = member(t1)
    member(t2)

    signin_and_visit(admin, admin_team_category_encounter_path(tc, encounter))

    side = "#encounter_#{encounter.id}_position_1 .pool-match__side--fighter_1"
    within(side) { select fighter.full_name, from: "kenshi_ids[]" }

    # No button: the change auto-submits. After the Turbo morph the side now
    # offers scoring (proving the bout was created) and still shows the pick
    # (proving the morph didn't blank the select).
    within(side) do
      expect(page).to have_button("M")
      expect(page).to have_select("kenshi_ids[]", selected: fighter.full_name)
    end
    expect(encounter.team_fights.find_by(position: 1)&.kenshi_1_id).to eq(fighter.id)
  end

  it "keeps scroll position on the admin pool page when a fighter is picked" do
    tc.update!(pool_size: 2)
    t1.update!(pool_number: 1)
    t2.update!(pool_number: 1)
    encounter = create(:encounter, team_category: tc, team_1: t1, team_2: t2, pool_number: 1)
    fighter = member(t1)
    member(t2)

    signin_and_visit(admin, admin_team_category_path(tc))
    page.driver.browser.manage.window.resize_to(1024, 500)

    find("summary", text: t1.name).click
    side = "#encounter_#{encounter.id}_position_1 .pool-match__side--fighter_1"
    scroll_to(find("#{side} select"))
    scrolled = page.evaluate_script("window.scrollY").to_i
    expect(scrolled).to be > 0 # the dropdown sits below the fold

    within(side) { select fighter.full_name, from: "kenshi_ids[]" }
    within(side) { expect(page).to have_button("M") } # wait for the update

    # A native submit would 302 to the standalone page and reset scroll to 0.
    expect(page).to have_current_path(admin_team_category_path(tc))
    expect(page.evaluate_script("window.scrollY").to_i).to be_within(60).of(scrolled)
  end
end
