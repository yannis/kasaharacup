# frozen_string_literal: true

require "rails_helper"

# Team twin of the individual freezes spec. The difference that matters is the
# broadcast shape: each surface here subscribes to a stream of its own, where
# the individual side has the panel, the cards and the tree sharing one.
RSpec.describe "Admin team category freezes" do
  let(:cup) { create(:cup) }
  let(:category) { create(:team_category, cup: cup, pool_size: 3) }
  let(:admin) { create(:user, :admin) }
  let(:sequence) { (1..).each }

  before { sign_in admin }

  def team(pool: nil)
    create(:team, team_category: category, name: "Team #{sequence.next}", pool_number: pool)
  end

  def drawn_pools
    2.times { team(pool: 1) }
    2.times { team(pool: 2) }
  end

  describe "pools" do
    it "freezes on POST and unfreezes on DELETE" do
      expect { post admin_team_category_pool_freeze_path(category) }
        .to change { category.reload.pools_frozen? }.from(false).to(true)

      expect { delete admin_team_category_pool_freeze_path(category) }
        .to change { category.reload.pools_frozen? }.from(true).to(false)
    end

    it "leaves the bracket flag alone" do
      post admin_team_category_pool_freeze_path(category)

      expect(category.reload).not_to be_bracket_frozen
    end

    it "redirects an HTML request back to the category with a notice" do
      post admin_team_category_pool_freeze_path(category)

      expect(response).to redirect_to(admin_team_category_path(category))
      expect(flash[:notice]).to be_present
    end

    it "replaces the pool surfaces, their chrome and the seeds panel" do
      drawn_pools

      post admin_team_category_pool_freeze_path(category), as: :turbo_stream

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("target=\"team_pools_#{category.id}\"")
      expect(response.body).to include("target=\"team_pool_unpooled_#{category.id}\"")
      expect(response.body).to include("target=\"team_pools_actions_#{category.id}\"")
      expect(response.body).to include("target=\"team_seeds_#{category.id}\"")
    end
  end

  describe "bracket" do
    it "freezes on POST and unfreezes on DELETE" do
      expect { post admin_team_category_bracket_freeze_path(category) }
        .to change { category.reload.bracket_frozen? }.from(false).to(true)

      expect { delete admin_team_category_bracket_freeze_path(category) }
        .to change { category.reload.bracket_frozen? }.from(true).to(false)
    end

    it "leaves the pools flag alone" do
      post admin_team_category_bracket_freeze_path(category)

      expect(category.reload).not_to be_pools_frozen
    end

    it "replaces the bracket, its chrome and the seeds panel" do
      drawn_pools
      create(:encounter, team_category: category, round: 1, position: 1)

      post admin_team_category_bracket_freeze_path(category), as: :turbo_stream

      expect(response).to have_http_status(:ok)
      expect(response.body)
        .to include("target=\"#{ActionView::RecordIdentifier.dom_id(category, :encounter_tree)}\"")
      expect(response.body).to include("target=\"team_bracket_actions_#{category.id}\"")
      expect(response.body).to include("target=\"team_seeds_#{category.id}\"")
    end
  end

  it "redirects a non-admin away" do
    sign_out admin
    sign_in create(:user)

    post admin_team_category_pool_freeze_path(category)

    expect(response).to have_http_status(:redirect)
    expect(category.reload).not_to be_pools_frozen
  end
end
