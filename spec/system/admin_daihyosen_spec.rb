# frozen_string_literal: true

require "rails_helper"

describe "Admin daihyosen on a tied bracket encounter", :js do
  include ActionView::RecordIdentifier

  let(:cup) { create(:cup) }
  let(:tc) { create(:team_category, cup: cup, team_size: 3) }
  let(:t1) { create(:team, team_category: tc) }
  let(:t2) { create(:team, team_category: tc) }
  let(:admin) { create(:user, :admin) }

  def stock(team, count)
    create_list(:kenshi, count, cup: cup).each do |k|
      create(:participation, category: tc, team: team, kenshi: k)
    end
  end

  # Mark every regular bout hikiwake. Drive each bout by its own row so a click
  # never races the panel morph from the previous one: every click replaces the
  # whole #encounter panel, so we click within a bout's stable row, then wait
  # for *that* bout's button to flip to "Hikiwake ✓" before moving on. (Matching
  # a bare "Hikiwake" + :first against the morphing panel is racy — the click
  # can land mid-morph or on a stale node.)
  def mark_all_hikiwake(encounter)
    encounter.team_fights.where(daihyosen: false).order(:position).each do |fight|
      within("##{dom_id(encounter)}_position_#{fight.position}") do
        click_button "Hikiwake", exact: true
        expect(page).to have_button("Hikiwake ✓", exact: true)
      end
    end
  end

  it "marks every bout hikiwake, auto-proposes the daihyosen, and decides it" do
    a = stock(t1, 3)
    b = stock(t2, 3)
    encounter = create(:encounter, team_category: tc, team_1: t1, team_2: t2)
    EncounterLineup.new(encounter).assign(t1, a.map(&:id))
    EncounterLineup.new(encounter).assign(t2, b.map(&:id))

    signin_and_visit(admin, admin_team_category_encounter_path(tc, encounter))

    mark_all_hikiwake(encounter)

    # The daihyosen bout is auto-created with each team's taisho. The header
    # text is uppercased by CSS (DAIHYŌSEN), so match case-insensitively.
    expect(page).to have_content(/daihyōsen/i)
    within("##{dom_id(encounter)}") do
      expect(page).to have_select("kenshi_1_id", selected: a.last.full_name)
      expect(page).to have_select("kenshi_2_id", selected: b.last.full_name)
    end

    # Score the daihyosen for team 1 -> encounter is decided.
    daihyosen = encounter.team_fights.find_by(daihyosen: true)
    within("##{dom_id(daihyosen)}") { click_button "M", match: :first }

    expect(page).to have_text(a.last.full_name) # winner shown
    expect(encounter.reload.winner).to eq t1
  end
end
