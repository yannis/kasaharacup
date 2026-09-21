# frozen_string_literal: true

require "rails_helper"

# Printed in the language of the session that asked for it, so every example
# states which one it reads: :en here, and one :fr example for the translation.
RSpec.describe TeamCategoryPoolOrderPdf, :en do
  let(:cup) { create(:cup) }
  let(:category) { create(:team_category, cup: cup, team_size: 3, pool_size: 3, out_of_pool: 1) }

  # The fill colour in effect when a run of text is drawn: Prawn emits an `scn`
  # operator whenever the colour changes, so the last one before the run is the
  # colour that run is printed in.
  def fill_colour_at(pdf, text)
    stream = pdf.render
    stream[0, stream.index(/<#{text.unpack1("H*")}>/i)]
      .scan(/([\d.]+ [\d.]+ [\d.]+) scn/).flatten.last
  end

  def pool_of(number, *names)
    names.each_with_index.map do |name, index|
      create(:team, team_category: category, name: name, pool_number: number, pool_position: index + 1)
    end
  end

  it "lists the ties in fighting order, alternating between the pools" do
    pool_of(1, "Alpha", "Bravo", "Charlie")
    pool_of(2, "Delta", "Echo", "Foxtrot")
    PoolEncounterGenerator.new(category).call

    texts = texts_in(described_class.new(category))

    expect(texts.grep(/\APool /)).to eq [
      "Pool 1 — 1/3", "Pool 2 — 1/3",
      "Pool 1 — 2/3", "Pool 2 — 2/3",
      "Pool 1 — 3/3", "Pool 2 — 3/3"
    ]
  end

  it "numbers the rows 1..N so a tie can be called by its number" do
    pool_of(1, "Alpha", "Bravo", "Charlie")
    pool_of(2, "Delta", "Echo")
    PoolEncounterGenerator.new(category).call

    texts = texts_in(described_class.new(category))

    expect(texts.grep(/\A\d+\z/)).to eq %w[1 2 3 4]
  end

  it "names both teams of every tie" do
    pool_of(1, "Alpha", "Bravo", "Charlie")
    PoolEncounterGenerator.new(category).call

    texts = texts_in(described_class.new(category))

    # Three ties over three teams: each team fights twice.
    expect(texts.count("ALPHA")).to eq 2
    expect(texts.count("BRAVO")).to eq 2
    expect(texts.count("CHARLIE")).to eq 2
  end

  it "keeps a tie's teams on the side the encounter puts them" do
    pool_of(1, "Alpha", "Bravo")
    PoolEncounterGenerator.new(category).call
    tie = category.encounters.sole

    texts = texts_in(described_class.new(category))

    # team_1 is the white side, team_2 the red one — the convention
    # TeamMatchSheet documents and the sheets draw.
    expect(texts.index(tie.team_1.poster_name)).to be < texts.index(tie.team_2.poster_name)
  end

  it "says what the list is in the language of the session", :fr do
    category.update!(name: "Team open")
    pool_of(1, "Alpha", "Bravo")
    PoolEncounterGenerator.new(category).call

    texts = texts_in(described_class.new(category))

    expect(texts).to include("Ordre des combats", "Blanc", "Rouge")
    expect(texts.grep(/\APoule /)).to eq ["Poule 1 — 1/1"]
  end

  it "heads the list with the category and what the list is" do
    # Named here rather than by the factory: a title too long for the box is
    # drawn as one run per line, and this example is about what the header
    # says, not about where it wraps.
    category.update!(name: "Team open")
    pool_of(1, "Alpha", "Bravo")
    PoolEncounterGenerator.new(category).call

    texts = texts_in(described_class.new(category))

    expect(texts).to include("TEAM OPEN", "Order of fights", "White", "Red")
  end

  # The cup name above the list is drawn in the cup's red and leaves that
  # colour behind: printed as it first was, every row of the list came out red.
  it "prints the list in black, under the red cup name" do
    pool_of(1, "Alpha", "Bravo")
    PoolEncounterGenerator.new(category).call

    pdf = described_class.new(category)

    expect(fill_colour_at(pdf, "White")).to eq "0.0 0.0 0.0"
    expect(fill_colour_at(pdf, "ALPHA")).to eq "0.0 0.0 0.0"
  end

  it "repeats the column headers when the order runs onto a second page" do
    12.times { |number| pool_of(number + 1, "Alpha #{number}", "Bravo #{number}", "Charlie #{number}") }
    PoolEncounterGenerator.new(category).call
    expect(category.encounters.count).to eq 36

    pdf = described_class.new(category)
    texts = texts_in(pdf)

    expect(pdf.page_count).to eq 2
    expect(texts.count("Red")).to eq 2
  end

  it "renders a category with no pool ties rather than an empty document" do
    pool_of(1, "Alpha", "Bravo")

    pdf = described_class.new(category)

    expect(pdf.page_count).to eq 1
    expect(texts_in(pdf)).to include("#{category.name} — no pool encounters")
  end
end
