# frozen_string_literal: true

require "rails_helper"

RSpec.describe FreezeHelper do
  let(:cup) { create(:cup) }
  let(:sequence) { (1..).each }

  def drawn_individual
    category = create(:individual_category, cup: cup, pool_size: 3, name: "Ind #{sequence.next}")
    create(:participation, category: category, kenshi: create(:kenshi, cup: cup),
      pool_number: 1, pool_position: 1)
    category
  end

  # One rule for "can the formation still be edited", read by the components,
  # the ActiveAdmin partials and the broadcasts that re-render them. Asserted
  # here so a change to it shows up in one place rather than as a scatter of
  # component failures.
  describe "#pool_formation_editable?" do
    it "is true only while neither flag is set" do
      category = create(:individual_category, cup: cup, pool_size: 3)
      expect(helper.pool_formation_editable?(category)).to be true

      category.freeze_pools!
      expect(helper.pool_formation_editable?(category)).to be false

      category.unfreeze_pools!
      # R5: a frozen bracket closes the formation too, because any membership
      # move clears the tree as a side effect.
      category.freeze_bracket!
      expect(helper.pool_formation_editable?(category)).to be false
    end
  end

  describe "#bracket_structure_editable?" do
    it "ignores the pools flag" do
      category = create(:individual_category, cup: cup, pool_size: 3)
      category.freeze_pools!
      expect(helper.bracket_structure_editable?(category)).to be true

      category.freeze_bracket!
      expect(helper.bracket_structure_editable?(category)).to be false
    end
  end

  describe "the cup panel counts" do
    it "counts across both category types and ignores what cannot be frozen" do
      frozen = drawn_individual
      drawn_individual
      create(:individual_category, cup: cup, pool_size: 3, name: "Undrawn")
      team = create(:team_category, cup: cup, pool_size: 3, name: "Team")
      create(:team, team_category: team, name: "Kyoto", pool_number: 1)
      frozen.freeze_pools!

      expect(helper.cup_pool_freezable_count(cup.reload)).to eq 3
      expect(helper.cup_pools_frozen_count(cup)).to eq 1
    end

    it "counts brackets separately" do
      category = drawn_individual
      create(:fight, individual_category: category)

      expect(helper.cup_bracket_freezable_count(cup.reload)).to eq 1
      expect(helper.cup_brackets_frozen_count(cup)).to eq 0

      category.freeze_bracket!
      expect(helper.cup_brackets_frozen_count(cup.reload)).to eq 1
    end
  end

  describe "#freeze_actions_dom_id" do
    # The page and the broadcast must target the same id, which is the whole
    # reason this lives in a helper rather than being spelled out per view.
    it "names a distinct container per surface" do
      individual = create(:individual_category, cup: cup, pool_size: 3)
      team = create(:team_category, cup: cup, pool_size: 3)

      ids = [
        helper.freeze_actions_dom_id(individual, :pools),
        helper.freeze_actions_dom_id(individual, :bracket),
        helper.freeze_actions_dom_id(team, :pools),
        helper.freeze_actions_dom_id(team, :bracket)
      ]

      expect(ids.uniq.size).to eq 4
    end
  end
end
