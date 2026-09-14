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

  it "gives every pool tie of the category its own sheet" do
    pool_of(1, "Alpha", "Bravo", "Charlie")
    pool_of(2, "Delta", "Echo")
    PoolEncounterGenerator.new(category).call

    # Three ties in the first pool (a cycle of three), one in the second.
    expect(category.encounters.count).to eq 4
    expect(described_class.new(category).page_count).to eq 4
  end

  # Five bout rows rather than three, and a name long enough to wrap, are what
  # a real category brings: the result table used to flow a fixed distance under
  # the bout rows, so once the names were printed into it a five-fighter sheet
  # ran its last row onto a second page. Every sheet is one page.
  [3, 5].each do |team_size|
    context "with #{team_size} fighters a side" do
      let(:category) { create(:team_category, cup: cup, team_size: team_size, pool_size: 2, out_of_pool: 1) }

      it "keeps each tie to a single page" do
        pool_of(1, "Do Academy Torino", "South West United", "Kendo Leman Sporting Club Number One")
        PoolEncounterGenerator.new(category).call

        pdf = described_class.new(category)

        expect(pdf.page_count).to eq category.encounters.count
      end
    end
  end

  it "names both teams of each tie on its sheet" do
    pool_of(1, "Alpha", "Bravo")
    PoolEncounterGenerator.new(category).call
    tie = category.encounters.sole

    texts = texts_in(described_class.new(category))

    expect(texts).to include(tie.team_1.poster_name, tie.team_2.poster_name)
  end

  it "prefills the team names and nothing else" do
    teams = pool_of(1, "Alpha", "Bravo")
    members = teams.flat_map do |team|
      Array.new(3) do
        kenshi = create(:kenshi, cup: cup)
        create(:participation, category: category, kenshi: kenshi, team: team)
        kenshi
      end
    end
    PoolEncounterGenerator.new(category).call

    texts = texts_in(described_class.new(category))

    # The sheet the desk writes on: a labelled row per fighting position with
    # nobody on it, a blank bout number, and an empty result table.
    expect(texts).to include("ALPHA", "BRAVO")
    expect(texts).to include("1. Sempo", "2. Chuken", "3. Taisho")
    expect(texts).to include("Combat n°", "Team", "Rank", "Wins", "Pts scored")
    expect(texts.count("x")).to eq 3
    members.each do |kenshi|
      expect(texts.join(" ")).not_to include(kenshi.last_name.upcase),
        "#{kenshi.full_name} should not be printed on the sheet"
    end
  end

  it "reads the ties off the encounters rather than recomputing the pairing" do
    pool_of(1, "Alpha", "Bravo", "Charlie")
    PoolEncounterGenerator.new(category).call
    # Delta belongs to the category but to no pool, so no pairing computed over
    # pool 1's teams could ever name it. Only the encounter records can.
    delta = create(:team, team_category: category, name: "Delta", pool_number: nil)
    category.encounters.order(:id).first.update!(team_1: delta)

    expect(texts_in(described_class.new(category))).to include("DELTA")
  end

  it "keeps a tie's teams on the side the encounter puts them" do
    pool_of(1, "Alpha", "Bravo")
    PoolEncounterGenerator.new(category).call
    tie = category.encounters.sole

    texts = texts_in(described_class.new(category))
    white, red = tie.team_1.poster_name, tie.team_2.poster_name

    # A side is identified by colour on both tables, and they list the two
    # colours in opposite orders: the name boxes are drawn white then red, the
    # result table red then white. team_1 is the white side on both.
    expect(texts.index(white)).to be < texts.index(red)
    expect(texts.rindex(white)).to be > texts.rindex(red)
  end

  it "renders a category with no pool ties rather than an empty document" do
    pool_of(1, "Alpha", "Bravo")

    pdf = described_class.new(category)

    expect(pdf.page_count).to eq 1
    expect(texts_in(pdf)).to include("#{category.name} — no pool encounters")
  end
end
