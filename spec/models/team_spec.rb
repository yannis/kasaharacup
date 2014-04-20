require 'spec_helper'

describe Team do
  it { should have_many :participations }
  it { should validate_presence_of(:name) }

  describe "a empty team" do
    let!(:team){ create :team, participations: [] }
    it {expect(team.participations.count).to eq 0}
    it {expect(team).to be_valid_verbose}

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
