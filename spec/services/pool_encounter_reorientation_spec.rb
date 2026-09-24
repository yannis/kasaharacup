# frozen_string_literal: true

require "rails_helper"

RSpec.describe PoolEncounterReorientation do
  let(:cup) { create(:cup) }
  let(:category) { create(:team_category, cup: cup, team_size: 3, pool_size: 3, out_of_pool: 1) }
  let!(:teams) do
    Array.new(3) { |index| create(:team, team_category: category, pool_number: 1, pool_position: index + 1) }
  end

  # The sides CyclicPairing's order gave a pool of three before
  # Pools::FightOrder: (1,2), (3,2), (3,1), team_1 first.
  def draw_the_old_way
    [[0, 1], [2, 1], [2, 0]].map do |white, red|
      category.encounters.create!(pool_number: 1, team_1: teams[white], team_2: teams[red])
    end
  end

  def sides
    category.encounters.order(:id).map { |encounter| [encounter.team_1, encounter.team_2] }
  end

  it "puts every encounter on the sides the fight order gives it" do
    draw_the_old_way

    described_class.new(category).call

    expect(sides).to eq [[teams[1], teams[0]], [teams[2], teams[1]], [teams[2], teams[0]]]
  end

  it "leaves encounters drawn by the generator as they are" do
    PoolEncounterGenerator.new(category).call

    expect { described_class.new(category).call }.not_to(change { sides })
  end

  it "takes a side's fighters and lineup flags along with its team" do
    encounter = draw_the_old_way.first
    white, red = create(:kenshi, cup: cup), create(:kenshi, cup: cup)
    create(:team_fight, encounter: encounter, kenshi_1: white, kenshi_2: red)
    encounter.update_columns(lineup_1_set: true, lineup_1_set_by_admin: true)

    described_class.new(category).call

    encounter.reload
    expect(encounter.team_2).to eq teams[0]
    expect([encounter.team_fights.sole.kenshi_1, encounter.team_fights.sole.kenshi_2]).to eq [red, white]
    expect([encounter.lineup_1_set, encounter.lineup_2_set]).to eq [false, true]
    expect([encounter.lineup_1_set_by_admin, encounter.lineup_2_set_by_admin]).to eq [false, true]
  end

  it "skips and reports a scored encounter" do
    encounter = draw_the_old_way.first
    fight = create(:team_fight, encounter: encounter)
    create(:fight_point, scorable: fight)

    result = described_class.new(category).call

    expect(result.skipped).to eq [encounter]
    expect(encounter.reload.team_1).to eq teams[0]
  end

  it "reports the swapped encounters with the sides they had" do
    draw_the_old_way

    swapped = described_class.new(category).call.swapped.sole

    expect([swapped.team_1, swapped.team_2]).to eq [teams[0], teams[1]]
  end

  it "only reports on a dry run" do
    draw_the_old_way

    result = described_class.new(category).call(dry_run: true)

    expect(result.swapped.size).to eq 1
    expect(category.encounters.order(:id).first.team_1).to eq teams[0]
  end
end
