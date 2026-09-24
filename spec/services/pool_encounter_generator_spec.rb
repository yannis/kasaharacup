# frozen_string_literal: true

require "rails_helper"

RSpec.describe PoolEncounterGenerator do
  let(:tc) { create(:team_category, pool_size: 3) }

  def pooled_team(number, position)
    create(:team, team_category: tc, pool_number: number, pool_position: position)
  end

  it "creates a pool of 3's ties in fighting order, white first: 2-1, 3-1, 3-2" do
    t1 = pooled_team(1, 1)
    t2 = pooled_team(1, 2)
    t3 = pooled_team(1, 3)

    described_class.new(tc).call

    pairs = tc.encounters.where(pool_number: 1).order(:id).map { |e| [e.team_1_id, e.team_2_id] }
    expect(pairs).to eq [[t2.id, t1.id], [t3.id, t1.id], [t3.id, t2.id]]
  end

  it "creates one encounter for a pool of 2" do
    a = pooled_team(2, 1)
    b = pooled_team(2, 2)
    described_class.new(tc).call
    expect(tc.encounters.where(pool_number: 2).pluck(:team_1_id, :team_2_id)).to eq [[b.id, a.id]]
  end

  it "is idempotent — a second call adds no duplicate encounters" do
    pooled_team(1, 1)
    pooled_team(1, 2)
    pooled_team(1, 3)
    described_class.new(tc).call
    expect { described_class.new(tc).call }.not_to change { tc.encounters.count }
  end
end
