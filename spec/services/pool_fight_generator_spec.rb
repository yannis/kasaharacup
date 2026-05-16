# frozen_string_literal: true

require "rails_helper"

RSpec.describe PoolFightGenerator do
  let(:cup) { create(:cup) }
  let(:category) { create(:individual_category, cup: cup) }

  def participate(category, pool_number:, pool_position:, pool_rank: nil)
    kenshi = create(:kenshi, cup: category.cup)
    create(:participation, category: category, kenshi: kenshi,
      pool_number: pool_number, pool_position: pool_position, pool_rank: pool_rank)
    kenshi
  end

  it "creates pool fights for a pool of 3" do
    k1 = participate(category, pool_number: 1, pool_position: 1)
    k2 = participate(category, pool_number: 1, pool_position: 2)
    k3 = participate(category, pool_number: 1, pool_position: 3)

    described_class.new(category).call

    fights = category.pool_fights.where(pool_number: 1).order(:number)
    expect(fights.size).to eq 3
    expect(fights.map { |f| [f.fighter_1_id, f.fighter_2_id] })
      .to eq [[k1.id, k2.id], [k3.id, k2.id], [k3.id, k1.id]]
    expect(fights.map(&:number)).to eq [1, 2, 3]
    expect(fights).to all(have_attributes(round: nil, position: nil, tiebreaker: false, draw: false))
  end

  it "skips pools that already have fights" do
    participate(category, pool_number: 1, pool_position: 1)
    participate(category, pool_number: 1, pool_position: 2)
    participate(category, pool_number: 2, pool_position: 1)
    participate(category, pool_number: 2, pool_position: 2)
    described_class.new(category).call
    expect { described_class.new(category).call }.not_to change { category.pool_fights.count }
  end

  it "generates only for missing pools when called again after a partial set" do
    participate(category, pool_number: 1, pool_position: 1)
    participate(category, pool_number: 1, pool_position: 2)
    described_class.new(category).call
    participate(category, pool_number: 2, pool_position: 1)
    participate(category, pool_number: 2, pool_position: 2)
    expect { described_class.new(category).call }
      .to change { category.pool_fights.where(pool_number: 2).count }.from(0).to(1)
  end

  it "handles pool of 2" do
    k1 = participate(category, pool_number: 1, pool_position: 1)
    k2 = participate(category, pool_number: 1, pool_position: 2)

    described_class.new(category).call

    fights = category.pool_fights.where(pool_number: 1)
    expect(fights.size).to eq 1
    expect([fights.first.fighter_1_id, fights.first.fighter_2_id]).to eq [k1.id, k2.id]
  end

  it "handles pool of 4" do
    kenshis = (1..4).map { |pos| participate(category, pool_number: 1, pool_position: pos) }

    described_class.new(category).call

    fights = category.pool_fights.where(pool_number: 1).order(:number)
    expect(fights.size).to eq 4
    expect(fights.map { |f| [f.fighter_1_id, f.fighter_2_id] })
      .to eq [
        [kenshis[0].id, kenshis[1].id],
        [kenshis[2].id, kenshis[1].id],
        [kenshis[2].id, kenshis[3].id],
        [kenshis[0].id, kenshis[3].id]
      ]
  end

  it "still generates the full match list when participations have duplicate pool_positions" do
    participate(category, pool_number: 1, pool_position: 1)
    participate(category, pool_number: 1, pool_position: 2)
    participate(category, pool_number: 1, pool_position: 2)
    participate(category, pool_number: 1, pool_position: 3)

    described_class.new(category).call

    expect(category.pool_fights.where(pool_number: 1).count).to eq 4
  end
end
