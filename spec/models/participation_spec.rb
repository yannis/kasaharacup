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
    it {expect{create :participation, category: nil}.to raise_error(ActiveRecord::RecordInvalid, "Validation failed: Category can't be blank")}
    context "when an individual_category_id is set" do
      let(:participation) {build :participation, category: mock_model(IndividualCategory)}
      it {expect(participation).to be_valid_verbose }
    end
  end
end
