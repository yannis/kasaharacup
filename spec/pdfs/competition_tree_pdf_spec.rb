# frozen_string_literal: true

require "rails_helper"

RSpec.describe CompetitionTreePdf do
  let(:cup) { create(:cup) }
  let(:category) { create(:individual_category, cup: cup, pool_size: 3, out_of_pool: 1) }

  it "renders a single-page bracket on one page" do
    create_qualified_participation(pool_number: 1, pool_rank: 1)
    create_qualified_participation(pool_number: 2, pool_rank: 1)
    IndividualCategoryBracketBuilder.new(category).call

    expect(described_class.new(category).page_count).to eq 1
  end

  it "splits a bracket whose first round exceeds one page into multiple panels" do
    # Each pool contributes one qualifier; with 20 pools the first round has
    # 16 fights (bracket_size 32 / 2), which is more than max_rows_per_page (10).
    20.times { |i| create_qualified_participation(pool_number: i + 1, pool_rank: 1) }
    IndividualCategoryBracketBuilder.new(category).call

    expect(described_class.new(category).page_count).to be > 1
  end

  def create_qualified_participation(pool_number:, pool_rank:)
    create(:participation,
      category: category,
      pool_number: pool_number,
      pool_position: pool_rank,
      pool_rank: pool_rank)
  end
end
