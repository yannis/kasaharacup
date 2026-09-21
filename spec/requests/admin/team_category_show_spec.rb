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

  # The Bracket panel chrome moved out of Arbre into a partial so a freeze
  # broadcast can replace it; the Pools panel gained one it never had. These
  # pin what the move carries.
  describe "panel chrome" do
    it "gives the Pools panel a freeze control once the draw exists" do
      category = create(:team_category, cup: cup, pool_size: 3, team_size: 3)
      create(:team, team_category: category, name: "Kyoto", pool_number: 1)

      get admin_team_category_path(category)

      expect(response.body).to include("team_pools_actions_#{category.id}")
      # The control is asserted by its endpoint, not its label: the admin
      # renders in French and the label is a translation.
      expect(response.body).to include(admin_team_category_pool_freeze_path(category))
    end

    it "keeps the bracket links and adds the freeze control" do
      category = create(:team_category, cup: cup, pool_size: 3, team_size: 3)
      create(:encounter, team_category: category, round: 1, position: 1)

      get admin_team_category_path(category)

      expect(response.body).to include("team_bracket_actions_#{category.id}")
      expect(response.body).to include("Update bracket")
      expect(response.body).to include("Force rebuild")
      expect(response.body).to include("Download PDF")
      expect(response.body).to include(admin_team_category_bracket_freeze_path(category))
    end

    # bracket_only? drops "Update bracket": there are no standings to fill in.
    it "drops the update link on a bracket-only category" do
      category = create(:team_category, cup: cup, pool_size: 1, team_size: 3)
      create(:encounter, team_category: category, round: 1, position: 1)

      get admin_team_category_path(category)

      expect(response.body).not_to include("Update bracket")
      expect(response.body).to include("Force rebuild")
    end
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
