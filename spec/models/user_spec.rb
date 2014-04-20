require 'spec_helper'

describe User do
  it { should belong_to :club }
  it { should have_many(:kenshis).dependent(:destroy) }

  it { should respond_to :first_name }
  it { should respond_to :last_name }
  it { should respond_to :email }
  it { should respond_to :password }
  it { should respond_to :admin }
  it { should respond_to :full_name }

  it { should validate_presence_of(:last_name) }
  it { should validate_presence_of(:first_name) }
  it { should validate_presence_of(:email) }
  it { should validate_uniqueness_of(:first_name).scoped_to(:last_name) }
end

describe "A basic user" do
  let(:user){create :user, first_name: "Yannis", last_name: "Jaquet"}
  it {expect(user).to be_valid_verbose}
  it {expect(user).to_not be_admin}
  it {expect(user.full_name).to eq "Yannis Jaquet"}
  it {expect(user.has_kenshis?).to be_false}

  context "when admin" do
    before{ user.update_attributes admin: true}
    it {expect(user).to be_admin}
  end

  context "with kenshi" do
    let!(:kenshi){create :kenshi, user: user}
    it {expect(user.has_kenshis?).to be_true}
  end
end
