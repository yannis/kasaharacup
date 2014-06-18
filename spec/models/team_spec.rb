require 'spec_helper'

describe Team do
  it { should have_many :participations }
  it { should have_many :kenshis }
  it { should validate_presence_of(:name) }
  it { should validate_uniqueness_of(:name).scoped_to(:team_category_id) }

  describe "a empty team" do
    let(:team_category){create :team_category, name: "team_cat"}
    let!(:team){ create :team, name: "SDK", team_category: team_category, participations: [] }
    it {expect(team.participations.count).to eq 0}
    it {expect(team).to be_valid_verbose}
    it {expect(team.name_and_status).to eql "SDK"}
    it {expect(team.name_and_category).to eql "SDK (team_cat)"}
    it {expect(team.name_and_category).to eql "SDK (team_cat)"}
    it {expect(team.poster_name).to eql "SDK"}
    it {expect(Team.empty.to_a).to include(team)}
    it {expect(Team.empty.to_a).to eq [team]}

    context "with 1 participation" do
      let!(:team_participation) {create :participation, team_id: team.id}
      before {team.reload}
      it {expect(team).to be_valid_verbose}
      it {expect(team_participation.team).to eq team}
      it {expect(Team.incomplete.all).to include(team)}
      it {expect(Team.incomplete).to eq [team]}
      it {expect(team.participations.count).to eq 1}
      it {expect(Team.empty.to_a).to_not include(team)}
    end

    # it "is included in Team.incomplete if it has less than 5 participations" do
    #   team.reload.should be_valid_verbose
    #   Team.incomplete.should include(team.reload)
    # end
  #   it "is valid if it has 5 participations" do
  #     team.stub!(:participations).and_return [mock_model(Participation),mock_model(Participation),mock_model(Participation),mock_model(Participation),mock_model(Participation)]
  #     team.should be_valid_verbose
  #   end
  #   it "is complete if it has 5 participations" do
  #     team.stub!(:participations).and_return [mock_model(Participation),mock_model(Participation),mock_model(Participation),mock_model(Participation),mock_model(Participation)]
  #     team.should be_complete
  #   end
  #   it "is complete if it has 6 participations" do
  #     team.stub!(:participations).and_return [mock_model(Participation),mock_model(Participation),mock_model(Participation),mock_model(Participation),mock_model(Participation),mock_model(Participation)]
  #     team.should be_complete
  #   end
  #   it "is incomplete if it has < 5 participations" do
  #     team.stub!(:participations).and_return [mock_model(Participation),mock_model(Participation),mock_model(Participation),mock_model(Participation)]
  #     team.should_not be_complete
  #   end
  #   it "is not valid if it has more than 6 participations" do
  #     team.stub!(:participations).and_return [mock_model(Participation),mock_model(Participation),mock_model(Participation),mock_model(Participation),mock_model(Participation),mock_model(Participation), mock_model(Participation)]
  #     team.should_not be_valid_verbose
  #     team.errors[:participations].should include "Une équipe ne peut rassembler plus de 6 combattants (seulement 5 se battront)."
  #   end
  end
end
