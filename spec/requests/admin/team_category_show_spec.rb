# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Admin team category show page" do
  let(:cup) { create(:cup) }
  let(:admin) { create(:user, :admin) }

  before { sign_in admin }

  def category_with_team(**attrs)
    category = create(:team_category, cup: cup, team_size: 3, **attrs)
    create(:team, team_category: category, name: "Kyoto")
    category
  end

  it "shows the seeding panel on a pooled category" do
    category = category_with_team(pool_size: 3)

    get admin_team_category_path(category)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("team_seeds_#{category.id}")
    expect(response.body).to include("Seeding")
  end

  # The individual panel sits behind a pool_size guard because a pool-less
  # individual category has no bracket at all. A bracket-only TEAM category
  # does, and its seeds decide the byes and the protected positions, so the
  # panel has to be reachable there too.
  it "shows the seeding panel on a bracket-only category" do
    category = category_with_team(pool_size: 1)

    get admin_team_category_path(category)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("team_seeds_#{category.id}")
  end

  it "renders no seeding panel before any team is registered" do
    category = create(:team_category, cup: cup, pool_size: 3, team_size: 3)

    get admin_team_category_path(category)

    expect(response).to have_http_status(:ok)
    expect(response.body).not_to include("team_seeds_#{category.id}")
  end

  # The panel owns the seed order now; a free-text field on the team form could
  # set 7 with no 1..6 and the two paths would disagree about the draw.
  it "offers no seed field on the team form" do
    category = category_with_team(pool_size: 3)

    get edit_admin_team_path(category.teams.first)

    expect(response).to have_http_status(:ok)
    expect(response.body).not_to include("team_seed")
  end
end
