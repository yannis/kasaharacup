# frozen_string_literal: true

require "rails_helper"

RSpec.describe TeamCategoryPoolMatchesPdf do
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

  # The label names the pool in the language of the session; these two read it,
  # so they state which language they expect.
  it "says which pool each sheet belongs to, stacked in fighting order", :en do
    pool_of(1, "Alpha", "Bravo", "Charlie")
    pool_of(2, "Delta", "Echo")
    PoolEncounterGenerator.new(category).call

    texts = texts_in(described_class.new(category))

    # A stack of loose sheets has to be sortable back into fighting order
    # without reading the team names off each one, and the running number is
    # the number the order list calls the tie by.
    expect(texts.grep(/Pool /))
      .to eq ["1 — Pool 1 — 1/3", "2 — Pool 1 — 2/3", "3 — Pool 1 — 3/3", "4 — Pool 2 — 1/1"]
  end

  # The label is placed, not flowed: a line added to the header pushes the bout
  # number down into the top border of the table under it.
  it "leaves every other line of the sheet exactly where the blank one has it", :en do
    pool_of(1, "Alpha", "Bravo")
    PoolEncounterGenerator.new(category).call

    blank = text_positions_in(TeamCategoryMatchSheetPdf.new(category))
    labelled = text_positions_in(described_class.new(category))
    added = ["ALPHA", "BRAVO"]

    expect(labelled.reject { |_, text| text.include?("Pool ") || added.include?(text) })
      .to eq(blank.reject { |_, text| added.include?(text) })
  end

  it "gives a club name room to sit on one line in both tables" do
    pool_of(1, "Do Academy Torino", "South West United")
    PoolEncounterGenerator.new(category).call

    texts = texts_in(described_class.new(category))

    # A name that wraps is drawn as two runs, so a whole name appearing twice —
    # once in its box, once in the result table — is the name fitting in both.
    expect(texts.count("DO ACADEMY TORINO")).to eq 2
    expect(texts.count("SOUTH WEST UNITED")).to eq 2
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
    expect(texts).to include("Team", "Rank", "Wins", "Pts scored")
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
