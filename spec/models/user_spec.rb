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
end

describe "A user" do
  context "without last_name" do
    it {expect{create :user, last_name: nil}.to raise_error(ActiveRecord::RecordInvalid, "Validation failed: Last name can't be blank")}
  end

  context "when a user with same first_name and last_name already exists" do
    let!(:user){create :user, first_name: "Yannis", last_name: "Jaquet"}
    it {expect{create :user, first_name: "Yannis", last_name: "Jaquet"}.to raise_error(ActiveRecord::RecordInvalid, "Validation failed: Last name has already been taken")}
  end
end


describe "A basic user" do
  let!(:cup) {create :cup}
  let(:user){create :user, first_name: "FIRST-J.-name nAme", last_name: "LAST-J.-name nAme", email: 'STUPIDLY.FORAMaTTED@EMAIL.COM'}

  it {expect(user).to be_valid_verbose}
  it {expect(user).to_not be_admin}
  it {expect(user.has_kenshis?).to be_false}

  it {expect(user.reload.last_name).to eq 'Last-J.-Name Name'}
  it {expect(user.reload.first_name).to eq 'First-J.-Name Name'}
  it {expect(user.full_name).to eq "First-J.-Name Name Last-J.-Name Name"}
  it {expect(user.reload.email).to eq 'stupidly.foramatted@email.com'}
  it {expect(user).to_not be_registered_for_cup(cup)}



    # context "if an kenshi with the same name exist" do
    #   let!(:kenshi){create :kenshi, first_name: user.first_name, last_name: user.last_name}

    #   it {expect(user.should be_registered}
    # end

  describe "a user with kenshis" do
    let(:user) {create :user}
    let!(:kenshi1) {create :kenshi, user_id: user.id, cup: cup}
    let!(:kenshi2) {create :kenshi, user_id: user.id, cup: cup}
    let!(:kenshi3) {create :kenshi, user_id: user.id, cup: cup}

    # it {expect(kenshi1.bill(:chf)).to eq 55}
    # it {expect(user.bill(:chf)).to eq 117}
  end

  context "when admin" do
    before{ user.update_attributes admin: true}
    it {expect(user).to be_admin}
  end

  context "with kenshi" do
    let!(:kenshi){create :kenshi, user: user}
    it {expect(user.has_kenshis?).to be_true}
  end
end


