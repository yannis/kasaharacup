# frozen_string_literal: true

require "rails_helper"

RSpec.describe TeamCategoryBracketPdf do
  let(:cup) { create(:cup) }
  let(:category) { create(:team_category, cup: cup, pool_size: 3, out_of_pool: 2) }

  def ranked_team(pool_number:, pool_rank:)
    create(:team, team_category: category, pool_number: pool_number, pool_rank: pool_rank)
  end

  it "renders a single-page bracket on one page" do
    ranked_team(pool_number: 1, pool_rank: 1)
    ranked_team(pool_number: 1, pool_rank: 2)
    ranked_team(pool_number: 2, pool_rank: 1)
    ranked_team(pool_number: 2, pool_rank: 2)
    TeamCategoryBracketBuilder.new(category).call

    expect(described_class.new(category).page_count).to eq 1
  end

  it "renders an empty-state page when no bracket has been generated" do
    expect(described_class.new(category).page_count).to eq 1
  end

  # Every half is padded to a power-of-two unit count, so nine pools draw 16
  # round-1 units of which 14 are byes. The geometry used to derive a node's
  # page from 2 ** (round - 1); this pins that every node still lands on a page
  # when the column is mostly byes.
  it "puts every node of a heavily-byed bracket on at least one page" do
    9.times do |i|
      ranked_team(pool_number: i + 1, pool_rank: 1)
      ranked_team(pool_number: i + 1, pool_rank: 2)
    end
    TeamCategoryBracketBuilder.new(category).call

    pdf = described_class.new(category)
    panels = pdf.send(:paginate_panels)
    placements = category.bracket_encounters.map { |encounter|
      panels.count { |panel| pdf.send(:encounter_belongs_to_panel?, encounter, panel) }
    }

    expect(category.bracket_encounters.where(round: 1).count).to eq 16
    expect(placements).to all be >= 1
  end

  it "splits a bracket whose first round exceeds one page into multiple panels" do
    # 20 pools each contributing 2 qualifiers gives a 32-team bracket: 16
    # first-round encounters, more than max_rows_per_page (10).
    20.times do |i|
      ranked_team(pool_number: i + 1, pool_rank: 1)
      ranked_team(pool_number: i + 1, pool_rank: 2)
    end
    TeamCategoryBracketBuilder.new(category).call

    expect(described_class.new(category).page_count).to be > 1
  end
end
