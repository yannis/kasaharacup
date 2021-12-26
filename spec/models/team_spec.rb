# frozen_string_literal: true

require "rails_helper"

RSpec.describe Team, type: :model do
  let!(:cup) { create :cup, start_on: 1.year.since }
  let(:team_category) { create :team_category, name: "team_cat", cup: cup }
  let(:team) { create :team, name: "SDK", team_category: team_category, participations: [] }

  it { is_expected.to have_many :participations }
  it { is_expected.to have_many :kenshis }
  it { is_expected.to validate_presence_of(:name) }
  it { is_expected.to validate_uniqueness_of(:name).scoped_to(:team_category_id) }

  describe "a empty team" do
    before { team.save! }

    it { expect(team.participations.count).to eq 0 }
    it { expect(team).to be_valid_verbose }
    it { expect(team).to be_incomplete }
    it { expect(team.name_and_status).to eql "SDK" }
    it { expect(team.name_and_category).to eql "SDK (team_cat)" }
    it { expect(team.poster_name).to eql "SDK" }
    it { expect(team.cup).to eql team_category.cup }
    it { expect(team_category.cup.teams).to match_array [team] }
    it { expect(described_class.empty.to_a).to include(team) }
    it { expect(described_class.empty.to_a).to eq [team] }

    context "with 1 participation" do
      let(:kenshi) { create :kenshi, dob: 20.years.ago, grade: "3Dan" }
      let!(:team_participation) {
        create :participation, team_id: team.id, category: team_category, kenshi: kenshi
      }

      before { team.reload }

      it { expect(team).to be_valid_verbose }
      it { expect(team_participation.team).to eq team }
      it { expect(described_class.incomplete.all).to include(team) }
      it { expect(described_class.incomplete).to eq [team] }
      it { expect(team.participations.count).to eq 1 }
      it { expect(team.fitness).to eq 0.1579 }
      it { expect(described_class.empty.to_a).not_to include(team) }
    end

    context "with 5 participations" do
      before {
        5.times do |i|
          create :participation, team: team, category: team_category,
kenshi: create(:kenshi, dob: 30.years.ago, grade: "#{i + 1}Dan", cup: cup)
        end
        team.reload
      }

      it { expect(team).to be_valid_verbose }
      it { expect(team).to be_complete }
      it { expect(team).to be_isvalid }
      it { expect(described_class.complete.all).to include(team) }
      it { expect(team.participations.count).to eq 5 }
      it { expect(team.fitness).to eq 0.4839 }
    end

    context "with 4 participations" do
      before {
        create_list :participation, 4, team: team, category: team_category
        team.reload
      }

      it { expect(team).to be_valid_verbose }
      it { expect(team).to be_incomplete }
      it { expect(team).to be_isvalid }
      it { expect(described_class.incomplete.all).to include(team) }
      it { expect(team.participations.count).to eq 4 }
    end

    context "with 6 participations" do
      before {
        create_list :participation, 6, team: team, category: team_category
        team.reload
      }

      it { expect(team).to be_valid_verbose }
      it { expect(team).to be_complete }
      it { expect(team).to be_isvalid }
      it { expect(team.participations.count).to eq 6 }
    end
  end
end
