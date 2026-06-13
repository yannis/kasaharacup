# frozen_string_literal: true

require "rails_helper"

describe "Admin bracket lineup auto-seed", :js do
  let(:cup) { create(:cup) }
  let(:category) { create(:team_category, cup: cup, pool_size: nil, team_size: 3) }
  let(:admin) { create(:user, :admin) }

  def stock(team, count)
    create_list(:kenshi, count, cup: cup).each do |k|
      create(:participation, category: category, team: team, kenshi: k)
    end
  end

  it "fills a fresh encounter's lineup on open so the fighters are draggable" do
    create_list(:team, 2, team_category: category).each { |team| stock(team, 3) }
    TeamCategoryBracketBuilder.new(category, random: Random.new(1)).call

    signin_and_visit(admin, admin_team_category_path(category))
    click_link "Encounter 1"

    panel = "turbo-frame#encounter_panel_team_category_#{category.id}"
    within(panel) do
      # The seed POST on open populated both sides; each filled card now carries
      # a drag handle, which only renders for a real (persisted) fighter.
      expect(page).to have_css(".pool-match__grip", minimum: 2)
    end

    # Seeding persists fighters but must NOT confirm the lineup (no premature tie).
    encounter = category.bracket_encounters.where(round: 1).order(:position).first
    expect(encounter.team_fights.where.not(kenshi_1_id: nil)).to be_present
    expect(encounter.reload.lineup_1_set?).to be false
  end
end
