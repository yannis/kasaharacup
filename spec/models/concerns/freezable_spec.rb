# frozen_string_literal: true

require "rails_helper"

# Both category types run the same contract: ActsAsCategory includes Freezable
# for both, and the guards, the panels and the cup-level freeze-all treat them
# interchangeably. What differs is only what "there is something to freeze"
# means — participations for one, teams for the other — so that pair gets a
# block per class.
RSpec.describe Freezable do
  let(:cup) { create(:cup) }

  shared_examples "a freezable category" do
    it "starts unfrozen on both flags" do
      expect(category).not_to be_pools_frozen
      expect(category).not_to be_bracket_frozen
    end

    it "freezes and unfreezes the pools" do
      expect { category.freeze_pools! }.to change { category.reload.pools_frozen? }.from(false).to(true)
      expect(category.pools_frozen_at).to be_present

      expect { category.unfreeze_pools! }.to change { category.reload.pools_frozen? }.from(true).to(false)
      expect(category.pools_frozen_at).to be_nil
    end

    it "freezes and unfreezes the bracket" do
      expect { category.freeze_bracket! }.to change { category.reload.bracket_frozen? }.from(false).to(true)
      expect(category.bracket_frozen_at).to be_present

      expect { category.unfreeze_bracket! }.to change { category.reload.bracket_frozen? }.from(true).to(false)
      expect(category.bracket_frozen_at).to be_nil
    end

    # The panel badge shows the timestamp, and two organizers pressing the same
    # button is the ordinary case rather than an error, so a second freeze has
    # to leave the recorded moment alone.
    it "keeps the first timestamp when frozen twice" do
      category.freeze_pools!
      category.freeze_bracket!
      pools_at = category.pools_frozen_at
      bracket_at = category.bracket_frozen_at

      travel 1.minute
      category.freeze_pools!
      category.freeze_bracket!

      expect(category.reload.pools_frozen_at).to eq pools_at
      expect(category.bracket_frozen_at).to eq bracket_at
    end

    # R5 aside, the flags never move together: "fix a pool score with the
    # bracket locked" is the whole reason there are two of them.
    it "keeps the two flags independent" do
      category.freeze_pools!
      expect(category.reload).not_to be_bracket_frozen

      category.unfreeze_pools!
      category.freeze_bracket!
      expect(category.reload).not_to be_pools_frozen
      expect(category).to be_bracket_frozen
    end

    it "scopes to the frozen of each flag" do
      other = another_category
      category.freeze_pools!
      other.freeze_bracket!

      expect(described_class.pools_frozen).to eq [category]
      expect(described_class.bracket_frozen).to eq [other]
    end

    # R7: pool_size and out_of_pool decide what a redraw produces and what the
    # bracket reads off the pools, so they are part of the formation the freeze
    # protects — changing them under a frozen draw makes the stored pools and
    # the settings disagree.
    describe "protected pool settings" do
      it "refuses a pool_size change while the pools are frozen" do
        category.freeze_pools!

        category.pool_size = 5

        expect(category).not_to be_valid
        expect(category.errors[:pool_size]).to be_present
      end

      it "refuses an out_of_pool change while the pools are frozen" do
        category.freeze_pools!

        category.out_of_pool = 2

        expect(category).not_to be_valid
      end

      it "accepts an unrelated change while the pools are frozen" do
        category.freeze_pools!

        expect(category.update(name: "Renamed while frozen")).to be true
      end

      it "accepts the same change once unfrozen" do
        category.freeze_pools!
        category.unfreeze_pools!

        expect(category.update(pool_size: 5)).to be true
      end

      # A bracket freeze says nothing about the draw: R2/R7 scope these to the
      # pools flag, so a pool_size change stays legal while only the bracket is
      # locked.
      it "accepts a pool_size change while only the bracket is frozen" do
        category.freeze_bracket!

        expect(category.update(pool_size: 5)).to be true
      end
    end

    # Freezable deliberately defines no #frozen? and no #freeze: they are Object
    # methods ActiveRecord itself relies on (ActiveRecord::Core#frozen? answers
    # @attributes.frozen?). Shadowing them breaks dup/clone and readonly
    # handling far from here, so this asserts Ruby's meaning survives.
    it "leaves Ruby's #frozen? meaning what Ruby means" do
      category.freeze_pools!
      category.freeze_bracket!
      expect(category).not_to be_frozen

      category.freeze
      expect(category).to be_frozen
    end
  end

  describe IndividualCategory do
    let(:category) { create(:individual_category, cup: cup, pool_size: 3) }

    def another_category
      create(:individual_category, cup: cup, pool_size: 3)
    end

    it_behaves_like "a freezable category"

    describe "#pools_freezable?" do
      it "is false before the draw" do
        expect(category).not_to be_pools_freezable
      end

      it "is true once a participation carries a pool number" do
        create(:participation, category: category, kenshi: create(:kenshi, cup: cup), pool_number: 1)

        expect(category).to be_pools_freezable
      end

      # #pools reads nothing when pool_size <= 1, so an unpooled category never
      # offers the button however many participants it has.
      it "is false for a pool-less category" do
        category.update!(pool_size: 1)
        create(:participation, category: category, kenshi: create(:kenshi, cup: cup))

        expect(category).not_to be_pools_freezable
      end
    end

    describe "#bracket_freezable?" do
      it "is false before the tree is generated" do
        expect(category).not_to be_bracket_freezable
      end

      it "is true once a bracket fight exists" do
        create(:fight, individual_category: category)

        expect(category).to be_bracket_freezable
      end

      it "is false when only pool fights exist" do
        create(:fight, :pool_fight, individual_category: category)

        expect(category).not_to be_bracket_freezable
      end
    end
  end

  describe TeamCategory do
    let(:category) { create(:team_category, cup: cup, pool_size: 3) }

    def another_category
      create(:team_category, cup: cup, pool_size: 3)
    end

    it_behaves_like "a freezable category"

    describe "#pools_freezable?" do
      it "is false before the draw" do
        expect(category).not_to be_pools_freezable
      end

      it "is true once a team carries a pool number" do
        create(:team, team_category: category, pool_number: 1)

        expect(category).to be_pools_freezable
      end

      # A bracket-only category has no pool phase to freeze, and dropping
      # pool_size to 1 leaves the previous draw's pool numbers on the teams —
      # so the bracket_only? half has to come first, exactly as it does in
      # TeamCategories::SeedsController#pool_cards?.
      it "is false for a bracket-only category still holding stale pool numbers" do
        create(:team, team_category: category, pool_number: 1)
        category.update!(pool_size: 1)

        expect(category).not_to be_pools_freezable
      end
    end

    describe "#bracket_freezable?" do
      it "is false before the bracket is generated" do
        expect(category).not_to be_bracket_freezable
      end

      it "is true once a bracket encounter exists" do
        create(:encounter, team_category: category, round: 1)

        expect(category).to be_bracket_freezable
      end

      # bracket_encounters requires a round: the manual "new encounter" form
      # makes one with neither a pool number nor a round, and that is not a tree.
      it "is false for an ad-hoc encounter with no round" do
        create(:encounter, team_category: category)

        expect(category).not_to be_bracket_freezable
      end

      it "is false when only pool encounters exist" do
        create(:encounter, team_category: category, pool_number: 1)

        expect(category).not_to be_bracket_freezable
      end
    end
  end
end
