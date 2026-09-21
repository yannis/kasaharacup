# frozen_string_literal: true

require "rails_helper"

# The model half of the pools freeze (R6). ActiveAdmin's plain Participation and
# Team forms permit pool_number / pool_position directly, so no controller guard
# can close that door — these rules can only live on the record.
#
# Both includers run the same contract, because the back door is the same shape
# on either side and a divergence would be a hole rather than a difference.
RSpec.describe FreezablePoolMember do
  let(:cup) { create(:cup) }

  shared_examples "a pool member of a freezable category" do
    it "refuses a pool_number change while the pools are frozen" do
      record = pooled_record
      category.freeze_pools!

      record.pool_number = 2

      expect(record).not_to be_valid
      expect(record.errors[:pool_number]).to be_present
    end

    it "refuses a pool_position change while the pools are frozen" do
      record = pooled_record
      category.freeze_pools!

      record.pool_position = 4

      expect(record).not_to be_valid
    end

    it "allows the same change once unfrozen" do
      record = pooled_record
      category.freeze_pools!
      category.unfreeze_pools!

      expect(record.update(pool_number: 2)).to be true
    end

    # The freeze covers the FORMATION, not the results: the pool phase is still
    # being played and recorded after the draw is settled.
    it "keeps pool_rank writable while the pools are frozen" do
      record = pooled_record
      category.freeze_pools!

      expect(record.update(pool_rank: 1)).to be true
    end

    # Its own message: the generic one reads "cannot be changed", which is not
    # what the admin just tried to do.
    it "refuses destroying a record that sits in a frozen pool" do
      record = pooled_record
      category.freeze_pools!

      expect(record.destroy).to be false
      expect(record.reload).to be_persisted
      expect(record.errors[:base])
        .to include I18n.t("activerecord.errors.messages.pools_frozen_destroy")
    end

    # Nothing in the frozen formation changes when a record that was never in a
    # pool goes away. And this is not a way out of the rule above: leaving a
    # pool means writing pool_number, which the validation refuses.
    it "allows destroying a record with no pool number" do
      record = unpooled_record
      category.freeze_pools!

      expect(record.destroy).to be_truthy
    end

    # Four parents dependent: :destroy into these rows. A guard that threw
    # unconditionally would make a frozen category — and its cup, and every
    # kenshi registered in it — undeletable, each failing with an opaque
    # pool_number error on a record the admin never touched.
    it "allows the cascade when its category is destroyed" do
      record = pooled_record
      category.freeze_pools!

      expect { category.destroy! }.not_to raise_error
      expect(described_class.where(id: record.id)).to be_empty
    end

    it "allows the cascade when the cup is destroyed" do
      record = pooled_record
      category.freeze_pools!

      expect { cup.destroy! }.not_to raise_error
      expect(described_class.where(id: record.id)).to be_empty
    end

    # R5, and the rule Admin::FreezeGuard#guard_frozen_pools! already applies on
    # the controller side: a frozen bracket closes the formation too, because
    # any move would clear the tree. The ActiveAdmin form is the only path that
    # reaches this one, which is exactly why it has to live here.
    it "refuses a pool_number change while only the bracket is frozen" do
      record = pooled_record
      category.freeze_bracket!

      record.pool_number = 2

      expect(record).not_to be_valid
      expect(record.errors[:pool_number]).to be_present
    end

    # The other half of the same back door. Both forms permit the category
    # association — team_category_id on one side, category_id / category_type on
    # the other — and reassigning a pooled record empties a slot in the
    # formation it leaves without either pool attribute changing.
    describe "moving between categories" do
      it "refuses taking a pooled record out of a frozen formation" do
        record = pooled_record
        destination = another_category
        category.freeze_pools!

        expect(reparent(record, to: destination)).to be false
        expect(category_of(record.reload)).to eq category
      end

      it "refuses putting a pooled record into a frozen formation" do
        record = pooled_record
        destination = another_category
        destination.freeze_pools!

        expect(reparent(record, to: destination)).to be false
        expect(category_of(record.reload)).to eq category
      end

      it "refuses the move while only the bracket is frozen" do
        record = pooled_record
        destination = another_category
        category.freeze_bracket!

        expect(reparent(record, to: destination)).to be false
      end

      # An unpooled row is part of no formation, so re-categorising it changes
      # nothing the freeze protects — and it is not a way around the rule
      # either, since emptying a pooled row means writing pool_number.
      it "allows moving a record that carries no pool number" do
        record = unpooled_record
        destination = another_category
        category.freeze_pools!

        expect(reparent(record, to: destination)).to be true
        expect(category_of(record.reload)).to eq destination
      end

      it "allows the move once unfrozen" do
        record = pooled_record
        destination = another_category
        category.freeze_pools!
        category.unfreeze_pools!

        expect(reparent(record, to: destination)).to be true
      end
    end
  end

  describe Participation do
    let(:category) { create(:individual_category, cup: cup, pool_size: 3) }
    let(:sequence) { (1..).each }

    def pooled_record
      create(:participation, category: category, kenshi: new_kenshi, pool_number: 1)
    end

    def unpooled_record
      create(:participation, category: category, kenshi: new_kenshi, pool_number: nil)
    end

    def new_kenshi
      n = sequence.next
      create(:kenshi, cup: cup, first_name: "First#{n}", last_name: "Last#{n}")
    end

    def another_category
      create(:individual_category, cup: cup, pool_size: 3)
    end

    def reparent(record, to:) = record.update(category: to)

    def category_of(record) = record.category

    it_behaves_like "a pool member of a freezable category"

    it "allows the cascade when its kenshi is destroyed" do
      record = pooled_record
      category.freeze_pools!

      expect { record.kenshi.destroy! }.not_to raise_error
      expect(described_class.where(id: record.id)).to be_empty
    end
  end

  describe Team do
    let(:category) { create(:team_category, cup: cup, pool_size: 3) }
    let(:sequence) { (1..).each }

    def pooled_record
      create(:team, team_category: category, name: "Team #{sequence.next}", pool_number: 1)
    end

    def unpooled_record
      create(:team, team_category: category, name: "Team #{sequence.next}", pool_number: nil)
    end

    def another_category
      create(:team_category, cup: cup, pool_size: 3)
    end

    def reparent(record, to:) = record.update(team_category: to)

    def category_of(record) = record.team_category

    it_behaves_like "a pool member of a freezable category"
  end
end
