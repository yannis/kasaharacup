# frozen_string_literal: true

require "rails_helper"

RSpec.describe TeamCategoryMatchSheetPdf do
  # Prawn writes each text run as a hex-encoded string inside a `[...] TJ`
  # operator, split into several chunks when kerning applies. Joining the chunks
  # of one operator gives back the cell's text.
  def texts_in(pdf)
    pdf.render.scan(/\[(.*?)\]\s*TJ/m).flatten.map do |run|
      run.scan(/<([0-9A-Fa-f]+)>/).flatten.map { |hex| [hex].pack("H*") }.join
    end
  end

  it "lists the five roles of a five-fighter category" do
    category = create(:team_category, team_size: 5)

    expect(texts_in(described_class.new(category)))
      .to include("1. Sempo", "2. Jiho", "3. Chuken", "4. Fukusho", "5. Taisho")
  end

  it "lists only the three roles of a three-fighter category" do
    category = create(:team_category, team_size: 3)
    texts = texts_in(described_class.new(category))

    expect(texts).to include("1. Sempo", "2. Chuken", "3. Taisho")
    expect(texts).not_to include("4. Fukusho", "5. Taisho")
  end

  it "draws one bout row per fighter" do
    expect(texts_in(described_class.new(create(:team_category, team_size: 3))).count("x")).to eq 3
    expect(texts_in(described_class.new(create(:team_category, team_size: 5))).count("x")).to eq 5
  end

  it "keeps the sheet on a single page" do
    expect(described_class.new(create(:team_category, team_size: 5)).page_count).to eq 1
    expect(described_class.new(create(:team_category, team_size: 3)).page_count).to eq 1
  end
end
