require 'spec_helper'

describe Participation do
  it {should belong_to :category}
  it {should belong_to :kenshi}
  it {should belong_to :team}

  it {should respond_to :pool_number}
  it {should respond_to :pool_position}
  it {should respond_to :ronin}

  # it {should validate_presence_of :kenshi_id}
end

describe "A participation" do
  context "without team_id an individual_category_id" do
    context "when an individual_category_id is set" do
      let(:participation) {build :participation, category: mock_model(IndividualCategory)}
      it {expect(participation).to be_valid_verbose }
    end
  end

  context "with ronin and team_category_id" do
    let(:cup) {create :cup}
    let(:kenshi) {create :kenshi, cup: cup}
    let(:team_category) {create :team_category, cup: cup}
    let!(:participation) {create :participation, category: team_category, ronin: true, kenshi: kenshi}

    it {expect(participation).to be_valid_verbose }
    it {expect(Participation.ronins.to_a).to eql [participation] }
  end

  context "for a kenshi" do
    let(:cup) { create :cup, start_on: 2.months.since }
    let(:individual_category) { create :individual_category, min_age: 8, max_age: 10, cup: cup }

    context "too young for the category" do
      let(:kenshi) { create :kenshi, dob: 6.years.ago.to_date, cup: cup }
      let(:participation) { build :participation, kenshi: kenshi, category: individual_category }
      it {
        participation.valid?
        expect(participation.errors[:category]).to eql ["Sorry, you're too young to participate to the #{individual_category.name} category!"]
      }
    end

    context "too old for the category" do
      let(:kenshi) { create :kenshi, dob: 14.years.ago.to_date, cup: cup }
      let(:participation) { build :participation, kenshi: kenshi, category: individual_category }

      it {
        participation.valid?
        expect(participation.errors[:category]).to eql ["Sorry, you're too old to participate to the #{individual_category.name} category!"]
      }
    end
  end
end
