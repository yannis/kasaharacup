require 'spec_helper'

describe "2 fighters" do
  let(:cup){create :cup, start_on: "2016-09-28"}
  let(:kenshi1){create :kenshi, cup: cup}
  let(:kenshi2){create :kenshi, cup: cup}
  it{expect(kenshi1).to act_as_fighter}

  context "in a fight" do
    let(:fight){create :fight, fighter_type: "Kenshi", fighter_1: kenshi1, fighter_2:kenshi2 }
    it {expect(fight).to be_valid_verbose}

    context "when kenshi2 win the fight" do
      before {kenshi2.win_fight fight}
      it {expect(fight.winner).to eq kenshi2}
    end
  end
end
