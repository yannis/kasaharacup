# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Admin team category brackets" do
  let(:cup) { create(:cup) }
  let(:category) { create(:team_category, cup: cup, pool_size: 1, out_of_pool: 1) }
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
end
