# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Admin encounter lineup seeds" do
  let(:cup) { create(:cup) }
  let(:tc) { create(:team_category, cup: cup, team_size: 3) }
  let(:t1) { create(:team, team_category: tc) }
  let(:t2) { create(:team, team_category: tc) }
  let(:admin) { create(:user, :admin) }

  before { sign_in admin }

  def members(team, count)
    create_list(:kenshi, count, cup: cup).each do |k|
      create(:participation, category: tc, team: team, kenshi: k)
    end
  end

  it "seeds the suggested order and confirms the lineups" do
    a = members(t1, 3)
    members(t2, 3)
    previous = create(:encounter, team_category: tc, team_1: t1, team_2: t2)
    EncounterLineup.new(previous).assign(t1, [a[2].id, a[0].id, a[1].id])

    fresh = create(:encounter, team_category: tc, team_1: t1, team_2: t2)
    post admin_team_category_encounter_lineup_seed_path(tc, fresh), as: :turbo_stream

    expect(response).to have_http_status(:ok)
    expect(fresh.team_fights.order(:position).map(&:kenshi_1_id)).to eq [a[2].id, a[0].id, a[1].id]
    expect(fresh.reload.lineup_1_set?).to be true
  end

  it "requires an admin" do
    sign_out admin
    fresh = create(:encounter, team_category: tc, team_1: t1, team_2: t2)

    post admin_team_category_encounter_lineup_seed_path(tc, fresh)

    expect(response).not_to have_http_status(:ok)
    expect(fresh.team_fights).to be_empty
  end
end
