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
    # Each pool contributes one qualifier, and the compact draw pairs them up
    # without padding: 30 pools give 16 first-round fights, more than
    # max_rows_per_page (14 on A4 landscape).
    30.times { |i| create_qualified_participation(pool_number: i + 1, pool_rank: 1) }
    IndividualCategoryBracketBuilder.new(category).call

    expect(described_class.new(category).page_count).to be > 1
  end

  # A kenshi's seat in the pool (pool_position) is not where they finished in
  # it (pool_rank): the round-1 prefix is the rank the slot was drawn from.
  #
  # Read off the card labels rather than the rendered stream: Inter is embedded
  # as a subset, so the stream holds glyph ids that PdfText cannot decode.
  it "prefixes a round-1 fighter with their pool rank, not their pool seat" do
    create_qualified_participation(pool_number: 1, pool_rank: 1, pool_position: 3)
    create_qualified_participation(pool_number: 2, pool_rank: 1, pool_position: 2)
    IndividualCategoryBracketBuilder.new(category).call
    labels = []
    allow_any_instance_of(described_class).to receive(:draw_card_text) # rubocop:disable RSpec/AnyInstance
      .and_wrap_original { |original, text, **options| labels << text.to_s && original.call(text, **options) }

    described_class.new(category.reload)

    expect(labels.grep(/\A\d+\.\d+ /).map { |label| label[/\A\d+\.\d+/] }).to match_array %w[1.1 2.1]
  end

  def create_qualified_participation(pool_number:, pool_rank:, pool_position: pool_rank)
    create(:participation,
      category: category,
      pool_number: pool_number,
      pool_position: pool_position,
      pool_rank: pool_rank)
  end
end
