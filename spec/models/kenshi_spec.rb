require 'spec_helper'

describe Kenshi do
  it {should belong_to :cup}
  it {should belong_to :user}
  it {should belong_to :club}
  it {should have_many(:participations).dependent(:destroy)}
  it {should have_many(:individual_categories).through(:participations)}
  it {should have_many(:teams).through(:participations)}

  it {should respond_to :first_name}
  it {should respond_to :last_name}
  it {should respond_to :dob}
  it {should respond_to :club}
  it {should respond_to :grade}
  it {should respond_to :email}

  it {should validate_presence_of :cup_id}
  it {should validate_presence_of :user_id}
  it {should validate_presence_of :first_name}
  it {should validate_presence_of :last_name}
  it {should validate_presence_of :dob}
  # it {should validate_presence_of :club_id}
  it {should validate_presence_of :grade}
  it {should validate_uniqueness_of(:last_name).scoped_to(:first_name)}

  it { should ensure_inclusion_of(:grade).in_array Kenshi::GRADES }

  it {should act_as_fighter}

  describe "A kenshi" do
    let(:kenshi){create :kenshi, first_name: "Yannis", last_name: "Jaquet"}
    it {expect(kenshi).to be_valid_verbose}
    it {expect(kenshi.full_name).to eq "Yannis Jaquet"}
  end

end
