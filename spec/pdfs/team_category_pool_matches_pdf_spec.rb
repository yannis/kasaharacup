# frozen_string_literal: true

require "rails_helper"

RSpec.describe TeamCategoryPoolMatchesPdf do
  # Prawn writes each text run as a hex-encoded string inside a `[...] TJ`
  # operator, split into several chunks when kerning applies. Joining the chunks
  # of one operator gives back the cell's text — in Windows-1252, the only
  # encoding Prawn's built-in fonts speak, so an em dash arrives as one byte.
  def texts_in(pdf)
    pdf.render.scan(/\[(.*?)\]\s*TJ/m).flatten.map do |run|
      run.scan(/<([0-9A-Fa-f]+)>/).flatten.map { |hex| [hex].pack("H*") }.join
        .force_encoding(Encoding::WINDOWS_1252)
        .encode(Encoding::UTF_8, invalid: :replace, undef: :replace)
    end
  end

  let(:cup) { create(:cup) }
  let(:category) { create(:team_category, cup: cup, team_size: 3, pool_size: 2, out_of_pool: 1) }

  def pool_of(number, *names)
    names.each_with_index.map do |name, index|
      create(:team, team_category: category, name: name, pool_number: number, pool_position: index + 1)
    end
  end

  it "gives each pool its own page" do
    pool_of(1, "Alpha", "Bravo")
    pool_of(2, "Charlie", "Delta")
    PoolEncounterGenerator.new(category).call

    expect(described_class.new(category).page_count).to eq 2
  end

  it "names both teams of every tie in the pool" do
    pool_of(1, "Alpha", "Bravo", "Charlie")
    PoolEncounterGenerator.new(category).call

    texts = texts_in(described_class.new(category))

    category.encounters.each do |encounter|
      expect(texts).to include(encounter.team_1.poster_name), "missing #{encounter.team_1.name}"
      expect(texts).to include(encounter.team_2.poster_name), "missing #{encounter.team_2.name}"
    end
    # One numbered row per tie, and a blank "x" between the two score boxes.
    expect(texts.count("x")).to eq category.encounters.count
  end

  it "reads the ties off the encounters rather than recomputing the pairing" do
    pool_of(1, "Alpha", "Bravo", "Charlie")
    PoolEncounterGenerator.new(category).call
    # Delta belongs to the category but to no pool, so no pairing computed over
    # pool 1's teams could ever name it. Only the encounter records can.
    delta = create(:team, team_category: category, name: "Delta", pool_number: nil)
    category.encounters.order(:id).first.update!(team_1: delta)

    texts = texts_in(described_class.new(category))

    expect(texts).to include("DELTA")
    # ...and the standings still list the pool, which Delta is not part of.
    expect(texts.count("DELTA")).to eq 1
    expect(texts).to include("ALPHA", "BRAVO", "CHARLIE")
  end

  it "says so when a pool has teams but no encounters yet" do
    pool_of(1, "Alpha", "Bravo")

    texts = texts_in(described_class.new(category))

    expect(texts).to include("No pool encounters generated.")
    expect(texts).to include("ALPHA", "BRAVO")
  end

  it "lists every team of the pool in the standings, with the on-screen columns" do
    pool_of(1, "Alpha", "Bravo", "Charlie")
    PoolEncounterGenerator.new(category).call

    texts = texts_in(described_class.new(category))

    expect(texts).to include("Rank", "W", "L", "H", "iW", "iL", "iH", "Pts+", "Pts-")
    expect(texts).to include("ALPHA", "BRAVO", "CHARLIE")
  end

  it "renders a category with no pools at all rather than an empty document" do
    bracket_only = create(:team_category, cup: cup, team_size: 3, pool_size: 1)
    create(:team, team_category: bracket_only)

    pdf = described_class.new(bracket_only)

    expect(pdf.page_count).to eq 1
    expect(texts_in(pdf)).to include("#{bracket_only.name} — no pools")
  end
end
