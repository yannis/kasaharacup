# frozen_string_literal: true

require "rails_helper"

RSpec.describe Participation do
  describe "Attributes" do
    let(:participation) { build(:participation) }

    it do
      expect(participation).to respond_to :pool_number
      expect(participation).to respond_to :pool_position
      expect(participation).to respond_to :ronin
      expect(participation).to respond_to :fighting_spirit
    end
  end

  describe "Associations" do
    let(:participation) { build(:participation) }

    it { expect(participation).to belong_to :category }
    it { expect(participation).to belong_to :kenshi }
    it { expect(participation).to belong_to(:team).optional }
  end

  describe "A participation" do
    context "without team_id an individual_category_id" do
      context "when an individual_category_id is set" do
        let(:participation) { build(:participation, category: create(:individual_category)) }

        it { expect(participation).to be_valid_verbose }
      end
    end

    context "with ronin and team_category_id" do
      let(:cup) { create(:cup) }
      let(:kenshi) { create(:kenshi, cup: cup) }
      let(:team_category) { create(:team_category, cup: cup) }
      let!(:participation) { create(:participation, category: team_category, ronin: true, kenshi: kenshi) }

      it { expect(participation).to be_valid_verbose }
      it { expect(described_class.ronins.to_a).to eql [participation] }
      it { expect(participation.cup).to eql cup }
    end

    context "when for a kenshi" do
      let(:cup) { create(:cup, start_on: 2.months.from_now) }
      let(:individual_category) { create(:individual_category, min_age: 8, max_age: 10, cup: cup) }

      context "when too young for the category" do
        let(:kenshi) { create(:kenshi, dob: 6.years.ago.to_date, cup: cup) }
        let(:participation) { build(:participation, kenshi: kenshi, category: individual_category) }

        it {
          participation.valid?
          expect(participation.errors[:category]).to contain_exactly("Désolé, mais vous êtes trop jeune pour
            participer à la catégorie #{individual_category.name}!".squish)
        }
      end

      context "when too old for the category" do
        let(:kenshi) { create(:kenshi, dob: 14.years.ago.to_date, cup: cup) }
        let(:participation) { build(:participation, kenshi: kenshi, category: individual_category) }

        it {
          participation.valid?
          expect(participation.errors[:category])
            .to contain_exactly("Désolé, mais vous êtes trop vieux pour participer à la
              catégorie #{individual_category.name}!".squish)
        }
      end
    end
  end
end
