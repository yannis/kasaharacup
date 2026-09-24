# frozen_string_literal: true

require "rails_helper"

RSpec.describe TeamCategoryPdfRecap do
  let(:cup) { create(:cup) }
  let(:category) { create(:team_category, cup: cup, name: "Team", team_size: 3, pool_size: 3, out_of_pool: 1) }

  def pool_of(number, *names)
    names.each_with_index.map do |name, index|
      create(:team, team_category: category, name: name, pool_number: number, pool_position: index + 1)
    end
  end

  it "lists every pool with its teams in pool position order" do
    pool_of(2, "Delta", "Echo")
    pool_of(1, "Alpha", "Bravo", "Charlie")
    category.teams.find_by!(name: "Alpha").update!(pool_position: 4)

    texts = texts_in(described_class.new(category))

    expect(texts.grep(/\APool \d\z/)).to eq ["Pool 1", "Pool 2"]
    expect(texts & %w[Alpha Bravo Charlie Delta Echo]).to eq %w[Bravo Charlie Alpha Delta Echo]
  end

  it "leaves out teams not yet in a pool" do
    pool_of(1, "Alpha", "Bravo")
    create(:team, team_category: category, name: "Latecomer")

    expect(texts_in(described_class.new(category))).not_to include("Latecomer")
  end

  it "moves to a new page rather than running a pool off the bottom" do
    12.times { |pool| pool_of(pool + 1, *Array.new(4) { |i| "Team #{pool + 1}.#{i + 1}" }) }

    pdf = described_class.new(category)

    expect(pdf.page_count).to be > 1
    expect(texts_in(pdf).grep(/\APool \d+\z/).size).to eq 12
  end
end
