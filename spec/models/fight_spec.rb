require 'spec_helper'

describe Fight do
  it {should belong_to :individual_category}
  it {should belong_to :winner}
  it {should belong_to :fighter_1}
  it {should belong_to :fighter_2}

  it {should respond_to :number}
  it {should respond_to :winner}
  it {should respond_to :score}
  it {should respond_to :parent_fight_1}
  it {should respond_to :parent_fight_2}

  # it {should validate_presence_of :fighter_1_id}
  it {should validate_presence_of :number}
  it {should validate_uniqueness_of(:number).scoped_to(:individual_category_id)}
end

describe "A fight" do
  let(:fight){create :fight}
  it {expect(fight).to be_valid_verbose}
end
