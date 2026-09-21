# frozen_string_literal: true

require "rails_helper"

# The server half of the pools freeze (R2, R4, R5, R12). Kept in one file
# rather than spread across the five specs of the guarded endpoints, because
# the requirements carry an exhaustive path table and this is where it gets
# checked off: a path that grows a new way in should fail here.
#
# 403, not 422: pool_membership_controller.js reads every 422 as "destructive,
# confirm and retry with force=true", and a freeze must never be force-able.
RSpec.describe "Admin pools freeze guard" do
  let(:cup) { create(:cup) }
  let(:admin) { create(:user, :admin) }
  let(:sequence) { (1..).each }

  before { sign_in admin }

  def refusal(response)
    expect(response).to have_http_status(:forbidden)
    JSON.parse(response.body).fetch("message")
  end

  describe "individual category" do
    let(:category) { create(:individual_category, cup: cup, pool_size: 3) }

    def participant(pool: nil, seed: nil)
      n = sequence.next
      kenshi = create(:kenshi, cup: cup, first_name: "First#{n}", last_name: "Last#{n}")
      create(:participation, category: category, kenshi: kenshi, pool_number: pool, seed: seed)
    end

    def drawn
      4.times { participant(pool: 1) }
    end

    it "refuses a pool membership move" do
      drawn
      participation = category.participations.first
      category.freeze_pools!

      patch admin_individual_category_pool_membership_path(category, participation),
        params: {to_pool_number: 2}, as: :turbo_stream

      expect(refusal(response)).to be_present
      expect(participation.reload.pool_number).to eq 1
    end

    it "refuses a seed change and an unseed" do
      participation = participant(seed: 1)
      category.freeze_pools!

      patch admin_individual_category_seed_path(category, participation),
        params: {to_position: 2}, as: :turbo_stream
      expect(response).to have_http_status(:forbidden)

      delete admin_individual_category_seed_path(category, participation), as: :turbo_stream
      expect(response).to have_http_status(:forbidden)
      expect(participation.reload.seed).to eq 1
    end

    it "refuses regenerating a pool's fights" do
      drawn
      PoolFightGenerator.new(category).call
      before_ids = category.pool_fights.pluck(:id)
      category.freeze_pools!

      post regenerate_pool_fights_admin_individual_category_path(category),
        params: {pool_number: 1}, as: :turbo_stream

      expect(refusal(response)).to eq I18n.t("admin.freezes.refused.pools")
      expect(category.pool_fights.pluck(:id)).to match_array before_ids
    end

    # guard_frozen_surface!, not guard_frozen_pools!: #regenerate destroy_alls
    # that one pool's fights and touches nothing else, so the refusal has no
    # business claiming the change would clear the tree and telling the
    # organizer to unfreeze a settled bracket for a pool-phase repair.
    it "names the bracket, not the tree it would clear, when only the BRACKET is frozen" do
      drawn
      PoolFightGenerator.new(category).call
      before_ids = category.pool_fights.pluck(:id)
      category.freeze_bracket!

      post regenerate_pool_fights_admin_individual_category_path(category),
        params: {pool_number: 1}, as: :turbo_stream

      expect(refusal(response)).to eq I18n.t("admin.freezes.refused.bracket")
      expect(category.pool_fights.pluck(:id)).to match_array before_ids
    end

    # The R5 message stays where R5 actually applies: a membership move really
    # does clear the tree as a side effect.
    it "still tells a membership move that it would clear the tree" do
      drawn
      participation = category.participations.first
      category.freeze_bracket!

      patch admin_individual_category_pool_membership_path(category, participation),
        params: {to_pool_number: 2}, as: :turbo_stream

      expect(refusal(response)).to eq I18n.t("admin.freezes.refused.bracket_blocks_pools")
    end

    # The pool card's own button posts to #regenerate for first-time
    # generation too, relabelling itself while the pool has no fights. With
    # nothing to destroy that is additive, so R2a keeps it available.
    it "still allows regenerate for a pool that has no fights yet" do
      drawn
      category.freeze_pools!

      expect {
        post regenerate_pool_fights_admin_individual_category_path(category),
          params: {pool_number: 1}, as: :turbo_stream
      }.to change { category.pool_fights.count }.from(0)

      expect(response).to have_http_status(:ok)
    end

    # R2a: both generators skip pools that already have fights and destroy
    # nothing, so first-time generation cannot alter a frozen formation.
    it "still allows first-time pool fight generation" do
      drawn
      category.freeze_pools!

      expect { post generate_pool_fights_admin_individual_category_path(category) }
        .to change { category.pool_fights.count }.from(0)

      expect(response).to have_http_status(:redirect)
    end

    # The freeze covers the formation, not the results.
    it "still allows recording a pool fight winner" do
      drawn
      PoolFightGenerator.new(category).call
      fight = category.pool_fights.first
      category.freeze_pools!

      patch admin_individual_category_pool_fight_path(category, fight),
        params: {pool_fight: {winner_id: fight.fighter_1_id, draw: false}}, as: :turbo_stream

      expect(response).to have_http_status(:ok)
      expect(fight.reload.winner_id).to eq fight.fighter_1_id
    end

    # R5: the move would clear the tree as a side effect, so an unfrozen pool
    # is otherwise a back door into a frozen bracket.
    it "refuses a pool membership move when only the BRACKET is frozen" do
      drawn
      participation = category.participations.first
      category.freeze_bracket!

      patch admin_individual_category_pool_membership_path(category, participation),
        params: {to_pool_number: 2}, as: :turbo_stream

      expect(refusal(response)).to be_present
      expect(participation.reload.pool_number).to eq 1
    end

    it "refuses the smart pool reset" do
      drawn
      category.freeze_pools!
      before_numbers = category.participations.order(:id).pluck(:pool_number)

      get reset_smart_pools_admin_individual_category_path(category)

      expect(response).to have_http_status(:redirect)
      expect(flash[:alert]).to be_present
      expect(category.participations.order(:id).pluck(:pool_number)).to eq before_numbers
    end
  end

  describe "team category" do
    let(:category) { create(:team_category, cup: cup, pool_size: 3) }

    def team(pool: nil, seed: nil)
      create(:team, team_category: category, name: "Team #{sequence.next}", pool_number: pool, seed: seed)
    end

    def drawn
      4.times { team(pool: 1) }
    end

    it "refuses a pool membership move" do
      drawn
      moved = category.teams.first
      category.freeze_pools!

      patch admin_team_category_pool_membership_path(category, moved),
        params: {to_pool_number: 2}, as: :turbo_stream

      expect(refusal(response)).to be_present
      expect(moved.reload.pool_number).to eq 1
    end

    it "refuses a seed change and an unseed" do
      seeded = team(seed: 1)
      category.freeze_pools!

      patch admin_team_category_seed_path(category, seeded), params: {to_position: 2}, as: :turbo_stream
      expect(response).to have_http_status(:forbidden)

      delete admin_team_category_seed_path(category, seeded), as: :turbo_stream
      expect(response).to have_http_status(:forbidden)
      expect(seeded.reload.seed).to eq 1
    end

    it "refuses redrawing the pools" do
      drawn
      category.freeze_pools!
      before_numbers = category.teams.order(:id).pluck(:pool_number)

      post generate_pools_admin_team_category_path(category)

      expect(response).to have_http_status(:redirect)
      expect(flash[:alert]).to be_present
      expect(category.teams.order(:id).pluck(:pool_number)).to eq before_numbers
    end

    # R2a again: PoolEncounterGenerator skips pools that already have them.
    it "still allows first-time pool encounter generation" do
      drawn
      category.freeze_pools!

      expect { post generate_pool_encounters_admin_team_category_path(category) }
        .to change { category.encounters.count }.from(0)
    end
  end
end
