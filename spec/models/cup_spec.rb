require 'spec_helper'

describe Cup do
  it {should have_many(:individual_categories).dependent(:destroy)}
  it {should have_many(:team_categories).dependent(:destroy)}
  it {should have_many(:events).dependent :destroy}
  it {should have_many(:kenshis).dependent :destroy}
  it {should have_many(:products).dependent :destroy}
  it {should respond_to(:start_on)}
  it {should respond_to(:end_on)}
  it {should respond_to(:deadline)}
  it {should respond_to(:year)}

  it {should validate_presence_of :start_on}
  it {should validate_presence_of :deadline}
  it {should validate_presence_of :adult_fees_chf}
  it {should validate_presence_of :adult_fees_eur}
  it {should validate_presence_of :junior_fees_chf}
  it {should validate_presence_of :junior_fees_eur}
  it {should validate_uniqueness_of :start_on}

  context "A cup created without deadline" do
    let(:cup){create :cup}

    it {expect(cup.deadline).to_not be_nil}
  end
end
