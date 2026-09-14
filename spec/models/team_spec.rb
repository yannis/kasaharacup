# frozen_string_literal: true

require "rails_helper"

RSpec.describe Team do
  let!(:cup) { create(:cup, start_on: 1.year.from_now) }
  let(:team_category) { create(:team_category, name: "team_cat", cup: cup) }
  let(:team) { create(:team, name: "SDK", team_category: team_category, participations: []) }

  it { expect(team).to have_many :participations }
  it { expect(team).to have_many :kenshis }
  it { expect(team).to validate_presence_of(:name) }
  it { expect(team).to validate_uniqueness_of(:name).scoped_to(:team_category_id) }

  describe "a empty team" do
    before { team.save! }

    it { expect(team.participations.count).to eq 0 }
    it { expect(team).to be_valid_verbose }
    it { expect(team).to be_incomplete }
    it { expect(team.name_and_status).to eql "SDK" }
    it { expect(team.name_and_category).to eql "SDK (team_cat)" }
    it { expect(team.poster_name).to eql "SDK" }
    it { expect(team.cup).to eql team_category.cup }
    it { expect(team_category.cup.teams).to contain_exactly(team) }
    it { expect(described_class.empty.to_a).to include(team) }
    it { expect(described_class.empty.to_a).to eq [team] }

    context "with 1 participation" do
      let(:kenshi) { create(:kenshi, dob: 20.years.ago, grade: "3Dan") }
      let!(:team_participation) {
        create(:participation, team_id: team.id, category: team_category, kenshi: kenshi)
      }

      before { team.reload }

      it { expect(team).to be_valid_verbose }
      it { expect(team_participation.team).to eq team }
      it { expect(team).to be_incomplete }
      it { expect(team).not_to be_isvalid }
      it { expect(team.participations.count).to eq 1 }
      it { expect(team.fitness).to eq 0.1364 }
      it { expect(described_class.empty.to_a).not_to include(team) }
    end

    context "with 2 participations" do
      before {
        create_list(:participation, 2, team: team, category: team_category)
        team.reload
      }

      it { expect(team).to be_incomplete }
      it { expect(team).not_to be_isvalid }
    end

    context "with 3 participations" do
      before {
        create_list(:participation, 3, team: team, category: team_category)
        team.reload
      }

      it { expect(team).to be_incomplete }
      it { expect(team).to be_isvalid }
    end

    context "with 5 participations" do
      before {
        5.times do |i|
          create(:participation, team: team, category: team_category,
            kenshi: create(:kenshi, dob: 30.years.ago, grade: "#{i + 1}Dan", cup: cup))
        end
        team.reload
      }

      it { expect(team).to be_valid_verbose }
      it { expect(team).to be_complete }
      it { expect(team).to be_isvalid }
      it { expect(team.participations.count).to eq 5 }
      it { expect(team.fitness).to eq 0.5 }
    end

    context "with 4 participations" do
      before {
        create_list(:participation, 4, team: team, category: team_category)
        team.reload
      }

      it { expect(team).to be_valid_verbose }
      it { expect(team).to be_incomplete }
      it { expect(team).to be_isvalid }
      it { expect(team.participations.count).to eq 4 }
    end

    context "with 6 participations" do
      before {
        create_list(:participation, 6, team: team, category: team_category)
        team.reload
      }

      it { expect(team).to be_valid_verbose }
      it { expect(team).to be_complete }
      it { expect(team).to be_isvalid }
      it { expect(team.participations.count).to eq 6 }
    end

    context "with more participations than the category can field" do
      before {
        create_list(:participation, 7, team: team, category: team_category)
        team.reload
      }

      it { expect(team).to be_valid_verbose }
      it { expect(team).to be_complete }
      it { expect(team).to be_isvalid }
      it { expect(team.participations.count).to eq 7 }
    end
  end

  describe "a team in a category of three" do
    let(:team_category) { create(:team_category, name: "team_cat", cup: cup, team_size: 3) }

    context "with 3 participations" do
      before {
        create_list(:participation, 3, team: team, category: team_category)
        team.reload
      }

      it { expect(team).to be_complete }
      it { expect(team).to be_isvalid }
      it { expect(team.name_and_status).to eql "SDK (complete)" }
    end

    context "with 2 participations" do
      before {
        create_list(:participation, 2, team: team, category: team_category)
        team.reload
      }

      it { expect(team).to be_incomplete }
      it { expect(team).to be_isvalid }
    end

    context "with 1 participation" do
      before {
        create_list(:participation, 1, team: team, category: team_category)
        team.reload
      }

      it { expect(team).to be_incomplete }
      it { expect(team).not_to be_isvalid }
    end
  end

  describe ".abandoned" do
    let(:other_category) { create(:team_category, name: "other_cat", cup: cup) }
    let!(:shell) { create(:team, name: "Shell", team_category: team_category) }
    let!(:manned) { create(:team, name: "Manned", team_category: team_category) }

    before { create(:participation, team: manned, category: team_category) }

    it "finds the empty team nothing else points at" do
      expect(described_class.abandoned).to contain_exactly(shell)
    end

    it "spares an empty team that holds a result" do
      shell.update!(rank: 1)

      expect(described_class.abandoned).to be_empty
    end

    it "spares an empty team that was seeded" do
      shell.update!(seed: 1)

      expect(described_class.abandoned).to be_empty
    end

    it "spares an empty team that was drawn into a pool" do
      shell.update!(pool_number: 1)

      expect(described_class.abandoned).to be_empty
    end

    it "spares an empty team that was drawn into an encounter" do
      create(:encounter, team_category: team_category, team_1: shell, team_2: manned)

      expect(described_class.abandoned).to be_empty
    end

    it "spares an empty team that won an encounter" do
      create(:encounter, team_category: team_category, team_2: manned, winner: shell)

      expect(described_class.abandoned).to be_empty
    end

    it "looks at its own encounters only" do
      create(:encounter, team_category: other_category)

      expect(described_class.abandoned).to contain_exactly(shell)
    end
  end

  describe "teams across categories of different sizes" do
    let(:small_category) { create(:team_category, name: "trios", cup: cup, team_size: 3) }
    let(:big_category) { create(:team_category, name: "quintets", cup: cup, team_size: 5) }
    let(:small_team) { create(:team, name: "Trio", team_category: small_category) }
    let(:big_team) { create(:team, name: "Quintet", team_category: big_category) }

    before {
      create_list(:participation, 3, team: small_team, category: small_category)
      create_list(:participation, 3, team: big_team, category: big_category)
    }

    it "counts three members as complete only where the category fields three" do
      expect(small_team).to be_complete
      expect(big_team).to be_incomplete
    end

    it "tells the two sizes apart on the isvalid? majority too" do
      expect(small_team).to be_isvalid
      expect(big_team).to be_isvalid

      small_team.participations.last.destroy
      big_team.participations.last.destroy

      expect(small_team.reload).to be_isvalid
      expect(big_team.reload).not_to be_isvalid
    end
  end

  describe "a team built before its category is assigned" do
    let(:orphan) { described_class.new(name: "SDK") }

    it { expect(orphan.team_size).to be_nil }
    it { expect(orphan).not_to be_complete }
    it { expect(orphan).to be_incomplete }
    it { expect(orphan).not_to be_isvalid }
    it { expect(orphan.name_and_status).to eql "SDK" }
  end
end
