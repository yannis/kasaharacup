# frozen_string_literal: true

require "rails_helper"

RSpec.describe PoolFightReorientation do
  let(:cup) { create(:cup) }
  let(:category) { create(:individual_category, cup: cup, pool_size: 3) }
  let!(:kenshis) do
    Array.new(3) do |index|
      create(:participation, category: category, pool_number: 1, pool_position: index + 1).kenshi
    end
  end

  # How PoolFightGenerator drew a pool of three before Pools::FightOrder:
  # CyclicPairing's (1,2), (3,2), (3,1), numbered in that order.
  def draw_the_old_way
    [[0, 1], [2, 1], [2, 0]].each_with_index.map do |(first, second), index|
      category.fights.create!(pool_number: 1, number: index + 1, fighter_type: "Kenshi",
        fighter_1_id: kenshis[first].id, fighter_2_id: kenshis[second].id)
    end
  end

  def fights
    category.pool_fights.order(:number).map { |fight| [fight.number, fight.fighter_1_id, fight.fighter_2_id] }
  end

  def reorient(dry_run: false)
    described_class.new(IndividualCategory.find(category.id)).call(dry_run: dry_run)
  end

  it "numbers the fights 1 <> 2, 1 <> 3, 2 <> 3 with the red fighter first" do
    draw_the_old_way

    expect(reorient.reordered).to eq [1]
    expect(fights).to eq [
      [1, kenshis[0].id, kenshis[1].id],
      [2, kenshis[0].id, kenshis[2].id],
      [3, kenshis[1].id, kenshis[2].id]
    ]
  end

  it "matches what the generator now draws, and leaves that alone" do
    PoolFightGenerator.new(category).call
    generated = fights
    Fight.where(individual_category: category).delete_all
    draw_the_old_way
    reorient

    expect(fights).to eq generated
    expect(reorient.reordered).to be_empty
  end

  it "keeps a kettei-sen after the pool's fights" do
    draw_the_old_way
    tiebreaker = category.fights.create!(pool_number: 1, number: 4, fighter_type: "Kenshi", tiebreaker: true,
      fighter_1_id: kenshis[0].id, fighter_2_id: kenshis[1].id)

    reorient

    expect(tiebreaker.reload.number).to eq 4
  end

  it "passes over a pool that has no fights yet" do
    expect(reorient).to have_attributes(reordered: [], skipped: [])
  end

  it "skips a pool with a scored fight" do
    draw_the_old_way.last.update!(winner_id: kenshis[2].id)

    expect { expect(reorient.skipped).to eq [1] }.not_to(change { fights })
  end

  it "only reports on a dry run" do
    draw_the_old_way

    expect { expect(reorient(dry_run: true).reordered).to eq [1] }.not_to(change { fights })
  end
end
