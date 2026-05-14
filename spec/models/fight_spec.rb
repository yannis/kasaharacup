# frozen_string_literal: true

require "rails_helper"

RSpec.describe Fight do
  describe "Associations" do
    let(:fight) { create(:fight) }

    it { expect(fight).to have_many(:fight_points).dependent(:destroy) }

    it do
      expect(fight).to belong_to(:individual_category)
      expect(fight).to belong_to(:winner).optional
      expect(fight).to belong_to(:fighter_1).optional
      expect(fight).to belong_to(:fighter_2).optional

      expect(fight).to respond_to :number
      expect(fight).to respond_to :winner
      expect(fight).to respond_to :score
      expect(fight).to respond_to :parent_fight_1
      expect(fight).to respond_to :parent_fight_2
      expect(fight).to respond_to :round
      expect(fight).to respond_to :position
      expect(fight).to respond_to :fighter_1_pool_number
      expect(fight).to respond_to :fighter_1_pool_rank
      expect(fight).to respond_to :fighter_2_pool_number
      expect(fight).to respond_to :fighter_2_pool_rank

      expect(fight).to validate_presence_of :number
      expect(fight).to validate_presence_of :round
      expect(fight).to validate_presence_of :position
      expect(fight).to validate_uniqueness_of(:position).scoped_to(:individual_category_id, :round)
    end
  end

  describe "A fight" do
    let(:cup) { create(:cup) }
    let(:category) { create(:individual_category, cup: cup) }
    let(:kenshi1) { create(:kenshi, cup: cup, participations: [build(:participation, category: category)]) }
    let(:kenshi2) { create(:kenshi, cup: cup, participations: [build(:participation, category: category)]) }
    let(:fight) { create(:fight, individual_category: category, fighter_1: kenshi1, fighter_2: kenshi2) }

    it { expect(fight).to be_valid_verbose }

    it "requires both fighters to participate in the fight category" do
      outsider = create(:kenshi)

      fight.fighter_2 = outsider

      expect(fight).not_to be_valid
      expect(fight.errors[:fighter_2]).to include("must participate in the category")
    end

    it "flags fighter_1 when it does not participate in the category" do
      outsider = create(:kenshi)

      fight.fighter_1 = outsider

      expect(fight).not_to be_valid
      expect(fight.errors[:fighter_1]).to include("must participate in the category")
    end

    it "requires the winner to be one of the fight competitors" do
      outsider = create(:kenshi, cup: cup, participations: [build(:participation, category: category)])

      fight.winner = outsider

      expect(fight).not_to be_valid
      expect(fight.errors[:winner]).to include("must be one of the fighters")
    end

    it "accepts the winner when it is one of the fight competitors" do
      fight.winner = kenshi1

      expect(fight).to be_valid_verbose
    end

    it "uses parent winners as resolved fighters" do
      parent_fight = create(:fight, individual_category: category, fighter_1: kenshi1, winner: kenshi1)
      child_fight = create(:fight,
        individual_category: category,
        fighter_1: nil,
        fighter_2: nil,
        parent_fight_1: parent_fight,
        round: 2,
        position: 1)

      expect(child_fight.fighters).to eq [kenshi1]
    end

    it "advances a bye fighter into the immediate next slot" do
      bye_parent = create(:fight, individual_category: category, fighter_1: kenshi1, fighter_2: nil)
      child = create(:fight,
        individual_category: category,
        fighter_1: nil,
        fighter_2: nil,
        parent_fight_1: bye_parent,
        round: 2,
        position: 1)

      expect(child.resolved_fighter_1).to eq kenshi1
    end

    it "does not propagate a bye fighter beyond the immediate next slot" do
      bye_parent = create(:fight, individual_category: category, fighter_1: kenshi1, fighter_2: nil)
      sibling = create(:fight, individual_category: category, number: 2)
      round_two = create(:fight,
        individual_category: category,
        fighter_1: nil,
        fighter_2: nil,
        parent_fight_1: bye_parent,
        parent_fight_2: sibling,
        round: 2,
        position: 1,
        number: 3)
      grand_child = create(:fight,
        individual_category: category,
        fighter_1: nil,
        fighter_2: nil,
        parent_fight_1: round_two,
        round: 3,
        position: 1,
        number: 4)

      expect(grand_child.resolved_fighter_1).to be_nil
    end

    it "still surfaces the lone fighter from a bye as a fighter (so admins can record the winner)" do
      bye_fight = create(:fight, individual_category: category, fighter_1: kenshi1, fighter_2: nil)

      expect(bye_fight.fighters).to eq [kenshi1]
    end

    it "broadcasts a competition tree replacement after the winner changes" do
      allow(ActionCable.server).to receive(:broadcast)

      ActiveJob::Base.queue_adapter.perform_enqueued_jobs = true
      begin
        fight.update!(winner: kenshi1)
      ensure
        ActiveJob::Base.queue_adapter.perform_enqueued_jobs = false
      end

      expect(ActionCable.server).to have_received(:broadcast).with(
        kind_of(String),
        include("competition_tree_individual_category_#{category.id}")
      )
    end

    it "enqueues the broadcast off the request thread" do
      ActiveJob::Base.queue_adapter.enqueued_jobs.clear

      fight.update!(winner: kenshi1)

      enqueued = ActiveJob::Base.queue_adapter.enqueued_jobs
      expect(enqueued.pluck(:job)).to include(Turbo::Streams::ActionBroadcastJob)
    end

    describe "winner cascade" do
      let(:kenshi3) { create(:kenshi, cup: cup, participations: [build(:participation, category: category)]) }
      let(:kenshi4) { create(:kenshi, cup: cup, participations: [build(:participation, category: category)]) }

      it "clears a child's winner when the parent's winner changes to a different fighter" do
        parent_1 = create(:fight, individual_category: category, fighter_1: kenshi1, fighter_2: kenshi2,
          number: 11, position: 1)
        parent_2 = create(:fight, individual_category: category, fighter_1: kenshi3, fighter_2: kenshi4,
          number: 12, position: 2)
        final = create(:fight, individual_category: category, fighter_1: nil, fighter_2: nil,
          parent_fight_1: parent_1, parent_fight_2: parent_2, round: 2, position: 1, number: 13)
        parent_1.update!(winner: kenshi1)
        parent_2.update!(winner: kenshi3)
        final.update!(winner: kenshi1)

        parent_1.update!(winner: kenshi2)

        expect(final.reload.winner).to be_nil
      end

      it "clears a child's winner when the parent's winner is cleared" do
        parent_1 = create(:fight, individual_category: category, fighter_1: kenshi1, fighter_2: kenshi2,
          number: 11, position: 1)
        parent_2 = create(:fight, individual_category: category, fighter_1: kenshi3, fighter_2: kenshi4,
          number: 12, position: 2)
        final = create(:fight, individual_category: category, fighter_1: nil, fighter_2: nil,
          parent_fight_1: parent_1, parent_fight_2: parent_2, round: 2, position: 1, number: 13)
        parent_1.update!(winner: kenshi1)
        parent_2.update!(winner: kenshi3)
        final.update!(winner: kenshi1)

        parent_1.update!(winner: nil)

        expect(final.reload.winner).to be_nil
      end

      it "leaves a child's winner alone when the parent saves without a winner change" do
        parent_1 = create(:fight, individual_category: category, fighter_1: kenshi1, fighter_2: kenshi2,
          number: 11, position: 1)
        parent_2 = create(:fight, individual_category: category, fighter_1: kenshi3, fighter_2: kenshi4,
          number: 12, position: 2)
        final = create(:fight, individual_category: category, fighter_1: nil, fighter_2: nil,
          parent_fight_1: parent_1, parent_fight_2: parent_2, round: 2, position: 1, number: 13)
        parent_1.update!(winner: kenshi1)
        parent_2.update!(winner: kenshi3)
        final.update!(winner: kenshi1)

        parent_1.touch

        expect(final.reload.winner).to eq kenshi1
      end

      it "cascades through multiple bracket levels" do # rubocop:disable RSpec/ExampleLength
        kenshi5 = create(:kenshi, cup: cup, participations: [build(:participation, category: category)])
        kenshi6 = create(:kenshi, cup: cup, participations: [build(:participation, category: category)])
        kenshi7 = create(:kenshi, cup: cup, participations: [build(:participation, category: category)])
        kenshi8 = create(:kenshi, cup: cup, participations: [build(:participation, category: category)])
        quarter_1 = create(:fight, individual_category: category, fighter_1: kenshi1, fighter_2: kenshi2,
          number: 21, position: 1)
        quarter_2 = create(:fight, individual_category: category, fighter_1: kenshi3, fighter_2: kenshi4,
          number: 22, position: 2)
        quarter_3 = create(:fight, individual_category: category, fighter_1: kenshi5, fighter_2: kenshi6,
          number: 23, position: 3)
        quarter_4 = create(:fight, individual_category: category, fighter_1: kenshi7, fighter_2: kenshi8,
          number: 24, position: 4)
        semi_1 = create(:fight, individual_category: category, fighter_1: nil, fighter_2: nil,
          parent_fight_1: quarter_1, parent_fight_2: quarter_2, round: 2, position: 1, number: 25)
        semi_2 = create(:fight, individual_category: category, fighter_1: nil, fighter_2: nil,
          parent_fight_1: quarter_3, parent_fight_2: quarter_4, round: 2, position: 2, number: 26)
        final = create(:fight, individual_category: category, fighter_1: nil, fighter_2: nil,
          parent_fight_1: semi_1, parent_fight_2: semi_2, round: 3, position: 1, number: 27)
        quarter_1.update!(winner: kenshi1)
        quarter_2.update!(winner: kenshi3)
        quarter_3.update!(winner: kenshi5)
        quarter_4.update!(winner: kenshi7)
        semi_1.update!(winner: kenshi1)
        semi_2.update!(winner: kenshi5)
        final.update!(winner: kenshi1)

        quarter_1.update!(winner: kenshi2)

        expect(semi_1.reload.winner).to be_nil
        expect(final.reload.winner).to be_nil
        expect(semi_2.reload.winner).to eq kenshi5
      end

      it "keeps the child's winner when the parent's new winner is still that child's recorded winner" do
        parent_1 = create(:fight, individual_category: category, fighter_1: kenshi1, fighter_2: kenshi2,
          number: 11, position: 1)
        parent_2 = create(:fight, individual_category: category, fighter_1: kenshi3, fighter_2: kenshi4,
          number: 12, position: 2)
        final = create(:fight, individual_category: category, fighter_1: nil, fighter_2: nil,
          parent_fight_1: parent_1, parent_fight_2: parent_2, round: 2, position: 1, number: 13)
        parent_1.update!(winner: kenshi1)
        parent_2.update!(winner: kenshi3)
        final.update!(winner: kenshi3)

        parent_1.update!(winner: kenshi2)

        expect(final.reload.winner).to eq kenshi3
      end
    end
  end

  describe "Pool fight validations" do
    let(:cup) { create(:cup) }
    let(:category) { create(:individual_category, cup: cup) }
    let(:kenshi1) { create(:kenshi, cup: cup, participations: [build(:participation, category: category)]) }
    let(:kenshi2) { create(:kenshi, cup: cup, participations: [build(:participation, category: category)]) }

    it "allows a pool fight to have nil round and position" do
      fight = build(:fight, :pool_fight, individual_category: category,
        fighter_1: kenshi1, fighter_2: kenshi2)
      expect(fight).to be_valid_verbose
    end

    it "still requires round and position for bracket fights" do
      fight = build(:fight, individual_category: category, fighter_1: kenshi1, fighter_2: kenshi2,
        round: nil, position: nil)
      expect(fight).not_to be_valid
      expect(fight.errors[:round]).to be_present
      expect(fight.errors[:position]).to be_present
    end

    it "lets a pool fight and a bracket fight share the same number" do
      create(:fight, individual_category: category, fighter_1: kenshi1, fighter_2: kenshi2, number: 1)
      pool_fight = build(:fight, :pool_fight, individual_category: category,
        fighter_1: kenshi1, fighter_2: kenshi2, number: 1)
      expect(pool_fight).to be_valid_verbose
    end

    it "scopes pool fight number uniqueness by pool_number" do
      create(:fight, :pool_fight, individual_category: category, pool_number: 1,
        fighter_1: kenshi1, fighter_2: kenshi2, number: 1)
      duplicate = build(:fight, :pool_fight, individual_category: category, pool_number: 1,
        fighter_1: kenshi1, fighter_2: kenshi2, number: 1)
      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:number]).to be_present
    end

    it "lets two different pools share a number sequence" do
      create(:fight, :pool_fight, individual_category: category, pool_number: 1,
        fighter_1: kenshi1, fighter_2: kenshi2, number: 1)
      fight = build(:fight, :pool_fight, individual_category: category, pool_number: 2,
        fighter_1: kenshi1, fighter_2: kenshi2, number: 1)
      expect(fight).to be_valid_verbose
    end

    it "rejects draw=true when pool_number is blank" do
      fight = build(:fight, individual_category: category, fighter_1: kenshi1, fighter_2: kenshi2,
        draw: true)
      expect(fight).not_to be_valid
      expect(fight.errors[:draw]).to include("only allowed on pool fights")
    end

    it "rejects draw=true when a winner is set" do
      fight = build(:fight, :pool_fight, individual_category: category,
        fighter_1: kenshi1, fighter_2: kenshi2, draw: true, winner: kenshi1)
      expect(fight).not_to be_valid
      expect(fight.errors[:draw]).to include("cannot coexist with a winner")
    end

    it "rejects tiebreaker=true when pool_number is blank" do
      fight = build(:fight, individual_category: category, fighter_1: kenshi1, fighter_2: kenshi2,
        tiebreaker: true)
      expect(fight).not_to be_valid
      expect(fight.errors[:tiebreaker]).to include("only allowed on pool fights")
    end

    it "rejects a tiebreaker missing fighter_1 or fighter_2" do
      fight = build(:fight, :tiebreaker, individual_category: category,
        fighter_1: kenshi1, fighter_2: nil)
      expect(fight).not_to be_valid
      expect(fight.errors[:fighter_2]).to be_present
    end

    it "accepts draw=true on a pool fight without a winner" do
      fight = build(:fight, :pool_fight, individual_category: category,
        fighter_1: kenshi1, fighter_2: kenshi2, draw: true)
      expect(fight).to be_valid_verbose
    end

    it "accepts a tiebreaker with both fighters present" do
      fight = build(:fight, :tiebreaker, individual_category: category,
        fighter_1: kenshi1, fighter_2: kenshi2)
      expect(fight).to be_valid_verbose
    end
  end
end
