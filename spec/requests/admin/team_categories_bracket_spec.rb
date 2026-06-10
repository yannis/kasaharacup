# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Admin team category brackets" do
  let(:cup) { create(:cup) }
  let(:category) { create(:team_category, cup: cup, pool_size: 3, out_of_pool: 1) }
  let(:admin) { create(:user, :admin) }

  before { sign_in admin }

  describe "POST /admin/team_categories/:id/generate_bracket" do
    it "generates bracket encounters for the category" do
      create(:team, team_category: category, pool_number: 1, pool_rank: 1)
      create(:team, team_category: category, pool_number: 2, pool_rank: 1)

      post generate_bracket_admin_team_category_path(category)

      expect(response).to redirect_to(admin_team_category_path(category))
      expect(category.bracket_encounters.where(round: 1).count).to eq 1
    end

    it "redirects non-admin users away" do
      sign_out admin
      sign_in create(:user)

      post generate_bracket_admin_team_category_path(category)

      expect(response).to redirect_to(root_url)
      expect(category.bracket_encounters).to be_empty
    end
  end

  describe "GET /admin/team_categories/:id (bracket panel)" do
    it "renders the bracket tree once encounters exist" do
      create(:team, team_category: category, pool_number: 1, pool_rank: 1)
      create(:team, team_category: category, pool_number: 2, pool_rank: 1)
      TeamCategoryBracketBuilder.new(category).call

      get admin_team_category_path(category)

      expect(response.body).to include("encounter_tree_team_category_#{category.id}")
    end
  end

  describe "GET a bracket encounter (framed in the tree)" do
    it "renders the encounter inside the tree frame with a back-to-tree link" do
      create(:team, team_category: category, pool_number: 1, pool_rank: 1)
      create(:team, team_category: category, pool_number: 2, pool_rank: 1)
      TeamCategoryBracketBuilder.new(category).call
      encounter = category.bracket_encounters.first

      get admin_team_category_encounter_path(category, encounter)

      expect(response.body).to include("encounter_tree_team_category_#{category.id}")
      expect(response.body).to include("Back to tree")
    end
  end

  describe "POST /admin/team_categories/:id/generate_bracket?rebuild=1" do
    it "force-rebuilds the bracket" do
      create(:team, team_category: category, pool_number: 1, pool_rank: 1)
      create(:team, team_category: category, pool_number: 2, pool_rank: 1)
      TeamCategoryBracketBuilder.new(category).call
      original_ids = category.bracket_encounters.pluck(:id)

      post generate_bracket_admin_team_category_path(category, rebuild: 1)

      expect(category.bracket_encounters.pluck(:id)).not_to match_array(original_ids)
    end
  end

  describe "bracket-only category" do
    let(:bracket_only) { create(:team_category, cup: cup, pool_size: nil) }

    it "generates a bracket straight from teams" do
      create_list(:team, 4, team_category: bracket_only)

      post generate_bracket_admin_team_category_path(bracket_only)

      expect(bracket_only.bracket_encounters.where(round: 1).count).to eq 2
      expect(bracket_only.bracket_encounters.where(round: 1).pluck(:team_1_pool_number).uniq).to eq [nil]
    end

    it "refuses pool generation server-side" do
      post generate_pools_admin_team_category_path(bracket_only)

      expect(response).to redirect_to(admin_team_category_path(bracket_only))
      expect(flash[:alert]).to be_present
    end

    it "refuses pool encounter generation server-side" do
      post generate_pool_encounters_admin_team_category_path(bracket_only)

      expect(response).to redirect_to(admin_team_category_path(bracket_only))
      expect(flash[:alert]).to be_present
      expect(bracket_only.encounters).to be_empty
    end

    it "hides pool action items and the Update bracket link" do
      create_list(:team, 4, team_category: bracket_only)
      TeamCategoryBracketBuilder.new(bracket_only).call

      get admin_team_category_path(bracket_only)

      expect(response.body).not_to include("Generate pools")
      expect(response.body).not_to include("Generate pool encounters")
      expect(response.body).not_to include("Update bracket")
      expect(response.body).to include("Force rebuild")
    end

    it "keeps pool actions for a pooled category" do
      get admin_team_category_path(category)

      expect(response.body).to include("Generate pools")
      expect(response.body).to include("Generate pool encounters")
    end
  end
end
