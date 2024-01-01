# frozen_string_literal: true

require "rails_helper"

RSpec.describe Kenshi do
  let(:cup) { create(:cup, start_on: 10.years.since) }

  describe "Attributes" do
    let(:kenshi) { build(:kenshi) }

    it do
      expect(kenshi).to respond_to :first_name
      expect(kenshi).to respond_to :last_name
      expect(kenshi).to respond_to :dob
      expect(kenshi).to respond_to :club
      expect(kenshi).to respond_to :grade
      expect(kenshi).to respond_to :email
      expect(kenshi).to respond_to :remarks
    end
  end

  describe "Associations" do
    let(:kenshi) { build(:kenshi) }

    it do
      expect(kenshi).to belong_to :cup
      expect(kenshi).to belong_to :user
      expect(kenshi).to belong_to :club
      expect(kenshi).to have_one(:personal_info).dependent(:destroy).inverse_of(:kenshi)
      expect(kenshi).to have_many(:participations).dependent(:destroy)
      expect(kenshi).to have_many(:individual_categories).through(:participations)
      expect(kenshi).to have_many(:teams).through(:participations)
      expect(kenshi).to have_many(:purchases).dependent(:destroy)
      expect(kenshi).to have_many(:products).through(:purchases)
    end
  end

  describe "Validations" do
    let(:kenshi) { create(:kenshi) }

    it do
      expect(kenshi).to validate_presence_of :first_name
      expect(kenshi).to validate_presence_of :last_name
      expect(kenshi).to validate_presence_of :dob
      expect(kenshi).to validate_presence_of :grade
      expect(kenshi).to validate_uniqueness_of(:last_name).scoped_to([:cup_id, :first_name]).case_insensitive
      expect(kenshi).to validate_inclusion_of(:grade).in_array Kenshi::GRADES
      expect(kenshi).to act_as_fighter
    end
  end

  describe "Callbacks" do
    describe "after_create_commit" do
      let(:kenshi) { build(:kenshi) }

      it do
        expect(kenshi).to receive(:notify_slack).once
        kenshi.save
      end
    end
  end

  describe "A kenshi" do
    let(:cup) { create(:cup, start_on: "#{Date.current.year}-12-29") }
    let(:club) { create(:club, name: "Shung Do Kwan") }
    let(:kenshi) {
      create(:kenshi, first_name: "Yannis", last_name: "Jaquet", female: false, club: club, dob: 20.years.ago,
        cup: cup)
    }

    it { expect(kenshi).to be_valid_verbose }
    it { expect(kenshi.full_name).to eq "Yannis Jaquet" }
    it { expect(kenshi).to be_adult }
    it { expect(kenshi.age_at_cup).to eq 20 }
    it { expect(kenshi.club.name).to eq "Shung Do Kwan" }
    it { expect(kenshi.poster_name).to eq "JAQUET" }

    context "when updated as junior" do
      before { kenshi.update dob: 12.years.ago }

      it { expect(kenshi).to be_junior }
      it { expect(kenshi.age_at_cup).to eq 12 }
    end
  end

  describe "A kenshi with badly formatted name and email" do
    let(:kenshi) {
      create(:kenshi, first_name: "FIRST-J.-sébastien mÜhlebäch", last_name: "LAST-J.-name nAme",
        email: "STUPIDLY.FORAMaTTED@EMAIL.COM", cup: cup)
    }

    it { expect(kenshi.norm_last_name).to eq "Last-J.-Name Name" }
    it { expect(kenshi.norm_first_name).to eq "First-J.-Sébastien Mühlebäch" }
    it { expect(kenshi.full_name).to eq "First-J.-Sébastien Mühlebäch Last-J.-Name Name" }
    it { expect(kenshi.reload.email).to eq "stupidly.foramatted@email.com" }
  end

  describe "fitness" do
    context "when kenshi aged 20 and 0Dan" do
      let(:kenshi) { build(:kenshi, dob: 20.years.ago, grade: "kyu", cup: cup) }

      it { expect(kenshi.fitness).to be 0.0 }
    end

    context "when kenshi aged 20 and 1Dan" do
      let(:kenshi) { build(:kenshi, dob: 20.years.ago, grade: "1Dan", cup: cup) }

      it { expect(kenshi.fitness).to be 0.0333 }
    end

    context "when kenshi aged 20 and 3Dan" do
      let(:kenshi) { build(:kenshi, dob: 20.years.ago, grade: "3Dan", cup: cup) }

      it { expect(kenshi.fitness).to be 0.1 }
    end

    context "when kenshi aged 60 and 8Dan" do
      let(:kenshi) { build(:kenshi, dob: 60.years.ago, grade: "3Dan", cup: cup) }

      it { expect(kenshi.fitness).to be 0.0429 }
    end
  end
end
