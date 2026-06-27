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
