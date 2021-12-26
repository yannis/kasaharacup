# frozen_string_literal: true

require "rails_helper"

RSpec.describe Fight, type: :model do
  it { is_expected.to belong_to(:individual_category) }
  it { is_expected.to belong_to(:winner).optional }
  it { is_expected.to belong_to(:fighter_1) }
  it { is_expected.to belong_to(:fighter_2) }

  it { is_expected.to respond_to :number }
  it { is_expected.to respond_to :winner }
  it { is_expected.to respond_to :score }
  it { is_expected.to respond_to :parent_fight_1 }
  it { is_expected.to respond_to :parent_fight_2 }

  # it {should validate_presence_of :fighter_1_id}
  it { is_expected.to validate_presence_of :number }
  it { is_expected.to validate_uniqueness_of(:number).scoped_to(:individual_category_id) }

  describe "A fight" do
    let(:cup) { create :cup }
    let(:kenshi1) { create :kenshi, cup: cup }
    let(:kenshi2) { create :kenshi, cup: cup }
    let(:fight) { create :fight, fighter_1_id: kenshi1.id, fighter_2_id: kenshi2.id }

    it { expect(fight).to be_valid_verbose }
  end
end
