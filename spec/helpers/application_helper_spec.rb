# frozen_string_literal: true

require "rails_helper"

RSpec.describe ApplicationHelper, :fr do
  describe "#cup_dates" do
    it "names both days of a two-day cup" do
      cup = build(:cup, start_on: Date.new(2026, 9, 26), end_on: Date.new(2026, 9, 27))
      expect(helper.cup_dates(cup)).to eq "les 26 et 27 septembre 2026"
    end

    it "names the single day of a one-day cup" do
      cup = build(:cup, start_on: Date.new(2026, 9, 26), end_on: nil)
      expect(helper.cup_dates(cup)).to eq "le 26 septembre 2026"
    end
  end

  describe "#ordinal" do
    it "ordinalizes in French" do
      expect(helper.ordinal(38)).to eq "38ème"
      expect(helper.ordinal(1)).to eq "1er"
    end

    it "ordinalizes in English" do
      I18n.with_locale(:en) do
        expect(helper.ordinal(38)).to eq "38th"
        expect(helper.ordinal(31)).to eq "31st"
      end
    end
  end

  describe "#cup_description" do
    it "describes the cup it is given rather than the current one" do
      current = build(:cup, start_on: Date.new(2026, 9, 26), end_on: Date.new(2026, 9, 27))
      helper.instance_variable_set(:@current_cup, current)
      other = build(:cup, start_on: Date.new(2030, 9, 28), end_on: Date.new(2030, 9, 29))
      expect(helper.cup_description(other)).to include("28 et 29 septembre 2030")
    end

    it "uses the future tense for an upcoming cup" do
      cup = build(:cup, start_on: Date.current + 1.month, end_on: Date.current + 1.month + 1.day)
      expect(helper.cup_description(cup)).to include("aura lieu")
    end

    it "uses the past tense for a cup that already happened" do
      cup = build(:cup, start_on: Date.new(2019, 9, 28), end_on: Date.new(2019, 9, 29))
      expect(helper.cup_description(cup)).to include("a eu lieu les 28 et 29 septembre 2019")
      expect(helper.cup_description(cup)).not_to include("aura lieu")
    end

    it "falls back to the dateless description for a canceled cup" do
      cup = build(:cup, start_on: Date.current + 1.month, canceled_at: Time.current)
      expect(helper.cup_description(cup)).to eq t("layout.description_short")
    end
  end
end
