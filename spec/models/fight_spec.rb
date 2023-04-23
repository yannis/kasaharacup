# frozen_string_literal: true

require "rails_helper"

RSpec.describe Fight do
  describe "Associations" do
    let(:fight) { create(:fight) }

    it do
      expect(fight).to belong_to(:individual_category)
      expect(fight).to belong_to(:winner).optional
      expect(fight).to belong_to(:fighter_1)
      expect(fight).to belong_to(:fighter_2)

      expect(fight).to respond_to :number
      expect(fight).to respond_to :winner
      expect(fight).to respond_to :score
      expect(fight).to respond_to :parent_fight_1
      expect(fight).to respond_to :parent_fight_2

      expect(fight).to validate_presence_of :number
      expect(fight).to validate_uniqueness_of(:number).scoped_to(:individual_category_id)
    end
  end

  describe "A fight" do
    let(:cup) { create(:cup) }
    let(:kenshi1) { create(:kenshi, cup: cup) }
    let(:kenshi2) { create(:kenshi, cup: cup) }
    let(:fight) { create(:fight, fighter_1_id: kenshi1.id, fighter_2_id: kenshi2.id) }

    it { expect(fight).to be_valid_verbose }
  end
end
