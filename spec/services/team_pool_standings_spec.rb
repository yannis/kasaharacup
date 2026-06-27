# frozen_string_literal: true

require "rails_helper"

RSpec.describe TeamPoolStandings do
  let(:tc) { create(:team_category, team_size: 3, pool_size: 3) }
  let(:teams) { Array.new(3) { |i| create(:team, team_category: tc, pool_number: 1, pool_position: i + 1) } }

  # Build a COMPLETE pool encounter between teams[a] and teams[b] with the given
  # per-position bout winners (1 = team_a kenshi, 2 = team_b kenshi, :draw). Builds
  # the team_fights directly (no EncounterLineup) so we needn't register each
  # kenshi as a team member just to exercise the standings.
  def encounter_between(a, b, results)
    enc = create(:encounter, team_category: tc, pool_number: 1, team_1: teams[a], team_2: teams[b])
    fights = results.each_index.map do |i|
      enc.team_fights.create!(position: i + 1,
        kenshi_1: create(:kenshi, cup: tc.cup), kenshi_2: create(:kenshi, cup: tc.cup))
    end
    enc.update!(lineup_1_set: true, lineup_2_set: true)
    results.each_with_index do |result, i|
      case result
      when 1 then create(:fight_point, scorable: fights[i], fighter_side: "fighter_1", kind: "men")
      when 2 then create(:fight_point, scorable: fights[i], fighter_side: "fighter_2", kind: "men")
      when :draw then fights[i].update!(draw: true)
      end
    end
    enc
  end

  it "ranks by team wins, then the cascade, and persists pool_rank" do
    teams # instantiate
    e1 = encounter_between(0, 1, [1, 1, 2]) # team0 beats team1 (2-1 bouts)
    e2 = encounter_between(0, 2, [1, 1, 1]) # team0 beats team2 (3-0)
    e3 = encounter_between(1, 2, [1, 1, 2]) # team1 beats team2 (2-1)
    encounters = [e1, e2, e3]

    rows = described_class.for(teams: teams, encounters: encounters)
    expect(rows.map { |r| r.team.id }).to eq [teams[0].id, teams[1].id, teams[2].id]
    expect(rows.first.team_wins).to eq 2

    described_class.persist_ranks!(teams: teams, encounters: encounters)
    expect(teams[0].reload.pool_rank).to eq 1
    expect(teams[1].reload.pool_rank).to eq 2
    expect(teams[2].reload.pool_rank).to eq 3
  end

  it "counts a drawn encounter as a draw for both teams" do
    teams
    enc = encounter_between(0, 1, [1, 2, :draw]) # 1 win each, ippons equal -> encounter draw
    rows = described_class.for(teams: teams, encounters: [enc])
    by_team = rows.index_by { |r| r.team.id }
    expect(by_team[teams[0].id].team_hikiwake).to eq 1
    expect(by_team[teams[1].id].team_hikiwake).to eq 1
  end

  it "flags an unbroken full tie and still assigns distinct ranks" do
    teams
    e1 = encounter_between(0, 2, [1, 1, 1]) # team0 beats team2
    e2 = encounter_between(1, 2, [1, 1, 1]) # team1 beats team2 (identically)
    rows = described_class.for(teams: teams, encounters: [e1, e2])
    top_two = rows.first(2)
    expect(top_two.map(&:tied)).to eq [true, true]
    expect(rows.last.tied).to be false # unambiguous last place is not flagged tied
    expect(rows.map(&:rank)).to eq [1, 2, 3] # distinct ranks despite the tie
  end

  it "returns unranked rows when no encounter is complete" do
    teams
    enc = create(:encounter, team_category: tc, pool_number: 1, team_1: teams[0], team_2: teams[1])
    enc.team_fights.create!(position: 1, kenshi_1: create(:kenshi, cup: tc.cup),
      kenshi_2: create(:kenshi, cup: tc.cup)) # no lineup flags set -> not complete

    rows = described_class.for(teams: teams, encounters: [enc])

    expect(rows.map(&:rank)).to all(be_nil)
    described_class.persist_ranks!(teams: teams, encounters: [enc])
    expect(teams.map { |t| t.reload.pool_rank }).to all(be_nil)
  end
end
