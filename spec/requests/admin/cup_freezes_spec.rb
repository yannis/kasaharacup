# frozen_string_literal: true

require "rails_helper"

# R13: the cup-level shortcut. Same RESTful shape as the per-category
# endpoints — create freezes, destroy unfreezes — applied across every
# category of one cup in a single transaction.
RSpec.describe "Admin cup freezes" do
  let(:cup) { create(:cup) }
  let(:admin) { create(:user, :admin) }
  let(:sequence) { (1..).each }

  before { sign_in admin }

  def drawn_individual
    category = create(:individual_category, cup: cup, pool_size: 3, name: "Ind #{sequence.next}")
    2.times do |i|
      create(:participation, category: category, kenshi: create(:kenshi, cup: cup),
        pool_number: 1, pool_position: i + 1)
    end
    category
  end

  def drawn_team
    category = create(:team_category, cup: cup, pool_size: 3, name: "Team #{sequence.next}")
    create(:team, team_category: category, name: "T#{sequence.next}", pool_number: 1)
    category
  end

  describe "pools" do
    it "freezes every category that has a draw" do
      individual = drawn_individual
      team = drawn_team

      post admin_cup_pool_freeze_path(cup)

      expect(individual.reload).to be_pools_frozen
      expect(team.reload).to be_pools_frozen
      expect(response).to redirect_to(admin_cup_path(cup))
      expect(flash[:notice]).to be_present
    end

    # R15's rule applied in bulk: nothing to freeze, nothing frozen.
    it "skips categories with nothing to freeze" do
      undrawn = create(:individual_category, cup: cup, pool_size: 3, name: "Undrawn")
      bracket_only = create(:team_category, cup: cup, pool_size: 1, name: "Bracket only")
      create(:team, team_category: bracket_only, name: "Solo")

      post admin_cup_pool_freeze_path(cup)

      expect(undrawn.reload).not_to be_pools_frozen
      expect(bracket_only.reload).not_to be_pools_frozen
    end

    it "unfreezes every category on DELETE" do
      individual = drawn_individual
      individual.freeze_pools!

      delete admin_cup_pool_freeze_path(cup)

      expect(individual.reload).not_to be_pools_frozen
    end

    it "leaves another cup's categories alone" do
      drawn_individual
      other_cup = create(:cup, year: cup.year + 1)
      other = create(:individual_category, cup: other_cup, pool_size: 3, name: "Elsewhere")
      create(:participation, category: other, kenshi: create(:kenshi, cup: other_cup),
        pool_number: 1, pool_position: 1)

      post admin_cup_pool_freeze_path(cup)

      expect(other.reload).not_to be_pools_frozen
    end

    it "reports how many were affected and how many were skipped" do
      drawn_individual
      create(:individual_category, cup: cup, pool_size: 3, name: "Undrawn")

      post admin_cup_pool_freeze_path(cup)

      expect(flash[:notice]).to include("1")
    end
  end

  describe "brackets" do
    it "freezes every category that has a bracket, and skips the rest" do
      with_tree = create(:individual_category, cup: cup, pool_size: 3, name: "Has tree")
      create(:fight, individual_category: with_tree)
      without = create(:individual_category, cup: cup, pool_size: 3, name: "No tree")

      post admin_cup_bracket_freeze_path(cup)

      expect(with_tree.reload).to be_bracket_frozen
      expect(without.reload).not_to be_bracket_frozen
    end

    it "does not touch the pools flag" do
      category = drawn_individual
      create(:fight, individual_category: category)

      post admin_cup_bracket_freeze_path(cup)

      expect(category.reload).not_to be_pools_frozen
    end
  end

  it "redirects a non-admin away" do
    category = drawn_individual
    sign_out admin
    sign_in create(:user)

    post admin_cup_pool_freeze_path(cup)

    expect(response).to have_http_status(:redirect)
    expect(category.reload).not_to be_pools_frozen
  end

  # The panel is the only way in, so it gets asserted on a real page render.
  describe "the cup page panel" do
    it "offers both freeze-all controls with a count of what is frozen" do
      drawn_individual
      create(:individual_category, cup: cup, pool_size: 3, name: "Undrawn")

      get admin_cup_path(cup)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(admin_cup_pool_freeze_path(cup))
      expect(response.body).to include(admin_cup_bracket_freeze_path(cup))
    end
  end
end
