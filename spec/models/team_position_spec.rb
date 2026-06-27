# frozen_string_literal: true

require "rails_helper"

RSpec.describe TeamPosition do
  describe ".label" do
    it "names the five roles of a full team" do
      labels = (1..5).map { |position| described_class.label(position, 5) }
      expect(labels).to eq ["1. Sempo", "2. Jiho", "3. Chuken", "4. Fukusho", "5. Taisho"]
    end

    it "names the three roles of a three-fighter team (leadoff, centre, anchor)" do
      labels = (1..3).map { |position| described_class.label(position, 3) }
      expect(labels).to eq ["1. Sempo", "2. Chuken", "3. Taisho"]
    end

    it "falls back to a plain position label for sizes without conventional roles" do
      expect(described_class.label(2, 4)).to eq "Position 2"
    end
  end
end
