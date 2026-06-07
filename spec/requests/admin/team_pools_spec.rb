# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Admin team pools" do
  let(:cup) { create(:cup) }
  let(:tc) { create(:team_category, cup: cup, pool_size: 3) }
  let(:admin) { create(:user, :admin) }

  before { sign_in admin }

  it "generates pools across the category's teams" do
    6.times { create(:team, team_category: tc) }

    post generate_pools_admin_team_category_path(tc)

    expect(tc.teams.where.not(pool_number: nil).count).to eq 6
    expect(response).to redirect_to(admin_team_category_path(tc))
  end

  it "generates pool encounters once pools exist" do
    3.times { |i| create(:team, team_category: tc, pool_number: 1, pool_position: i + 1) }

    post generate_pool_encounters_admin_team_category_path(tc)

    expect(tc.encounters.where(pool_number: 1).count).to eq 3 # round-robin of 3
    expect(response).to redirect_to(admin_team_category_path(tc))
  end

  it "renders the admin show page with the pool panel (admin best_in_place path)" do
    3.times { |i| create(:team, team_category: tc, pool_number: 1, pool_position: i + 1) }

    get admin_team_category_path(tc)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Pool 1")
  end

  it "redirects non-admins away" do
    sign_out admin
    sign_in create(:user)
    post generate_pools_admin_team_category_path(tc)
    expect(response).to redirect_to(root_url)
  end
end
