# frozen_string_literal: true

require "rails_helper"

RSpec.describe Cup, type: :model do
  let(:cup) { build(:cup) }

  it { expect(cup).to have_many(:individual_categories).dependent(:destroy) }
  it { expect(cup).to have_many(:team_categories).dependent(:destroy) }
  it { expect(cup).to have_many(:events).dependent :destroy }
  it { expect(cup).to have_many(:headlines).dependent :destroy }
  it { expect(cup).to have_many(:kenshis).dependent :destroy }
  it { expect(cup).to have_many(:products).dependent :destroy }
  it { expect(cup).to respond_to(:start_on) }
  it { expect(cup).to respond_to(:end_on) }
  it { expect(cup).to respond_to(:deadline) }
  it { expect(cup).to respond_to(:year) }
  it { expect(cup).to respond_to(:participations) }

  it { expect(cup).to validate_presence_of :start_on }
  # it {expect(cup).to validate_presence_of :deadline} set in before save
  it { expect(cup).to validate_presence_of :adult_fees_chf }
  it { expect(cup).to validate_presence_of :adult_fees_eur }
  it { expect(cup).to validate_presence_of :junior_fees_chf }
  it { expect(cup).to validate_presence_of :junior_fees_eur }
  it { expect(cup).to validate_uniqueness_of :start_on }

  describe "A cup without deadline" do
    let(:cup) { create :cup }

    it { expect(cup.deadline).not_to be_nil }
  end

  describe "4 cups, 2 pasts, 2 futures" do
    before { described_class.destroy_all }

    let!(:cup1) { create :cup, start_on: Date.current - 2.years }
    let!(:cup2) { create :cup, start_on: Date.current - 1.year }
    let!(:cup3) { create :cup, start_on: Date.current + 1.year }
    let!(:cup4) { create :cup, start_on: Date.current + 2.years }

    it { expect(cup1).to be_past }
    it { expect(described_class.count).to be 4 }
    it { expect(cup4).not_to be_past }
    it { expect(described_class.all).to match_array [cup1, cup2, cup3, cup4] }
    it { expect(described_class.past).to match_array [cup1, cup2] }
    it { expect(described_class.future).to match_array [cup3, cup4] }
  end

  describe "#canceled?" do
    let(:cup) { build(:cup) }

    it { expect(cup).not_to be_canceled }

    context "when canceled_at is set" do
      before { cup.canceled_at = Time.current }

      it { expect(cup).to be_canceled }
    end
  end
end
