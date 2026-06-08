# frozen_string_literal: true

require "rails_helper"

# Integration spec spanning the builder, advancement callbacks, and lineup scoring.
RSpec.describe "Team bracket advancement past round 1" do # rubocop:disable RSpec/DescribeClass
  let(:cup) { create(:cup) }
  # team_size must be in [3, 5] (TeamCategory validation), so teams field 3 members.
  let(:category) { create(:team_category, cup: cup, team_size: 3, pool_size: 1, out_of_pool: 1) }

  def ranked_team(pool_number)
    team = create(:team, team_category: category, pool_number: pool_number, pool_rank: 1)
    create_list(:kenshi, 3, cup: cup).each do |k|
      create(:participation, category: category, team: team, kenshi: k)
    end
    team
  end

  it "fills a round-2 slot from a scored round-1 encounter and lets it be scored" do
    [1, 2, 3, 4].each { |pool_number| ranked_team(pool_number) }

    TeamCategoryBracketBuilder.new(category).call
    round_one = category.bracket_encounters.where(round: 1).order(:position).to_a
    final = category.bracket_encounters.find_by(round: 2)

    # Score the first round-1 encounter: team_1 takes the first bout, going 1–0
    # in wins, so it is the derived encounter winner.
    enc = round_one.first
    EncounterLineup.new(enc).assign(enc.team_1, enc.team_1.kenshis.map(&:id))
    EncounterLineup.new(enc).assign(enc.team_2, enc.team_2.kenshis.map(&:id))
    bout = enc.team_fights.order(:position).first
    create(:fight_point, scorable: bout, fighter_side: "fighter_1", kind: "men")

    enc.reload
    expect(enc.winner).to eq enc.team_1

    # The winner has advanced into the final's matching slot.
    final.reload
    expect([final.team_1_id, final.team_2_id]).to include(enc.team_1_id)

    # And that slot is now scorable (no InvalidLineup).
    advanced = enc.team_1
    expect {
      EncounterLineup.new(final).assign(advanced, advanced.kenshis.map(&:id))
    }.not_to raise_error
  end
end
