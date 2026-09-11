# frozen_string_literal: true

require "rails_helper"

RSpec.describe AcceptLanguage do
  def best(header) = described_class.best_locale(header)

  it "returns nothing when the request sends no header" do
    expect(best(nil)).to be_nil
  end

  it "returns nothing when the header is empty" do
    expect(best("")).to be_nil
  end

  it "returns nothing when the visitor asks only for languages the site does not offer" do
    expect(best("de-DE,de;q=0.9")).to be_nil
  end

  it "reads the language from a region-qualified tag" do
    expect(best("en-GB,en;q=0.9")).to eq :en
  end

  # The bug in issue #1267: the anchored scan read only the first tag, so a
  # visitor offered English second was given the default instead.
  it "skips a leading language the site does not offer" do
    expect(best("de-DE,de;q=0.9,en;q=0.8")).to eq :en
  end

  # RFC 9110 language tags are case-insensitive.
  it "matches regardless of case" do
    expect(best("EN-US,EN;q=0.9")).to eq :en
  end

  # Header order is not preference order, and both locales are available here,
  # so reading the header left to right would pick the one deprioritised 9:1.
  it "honours q-values rather than header order" do
    expect(best("de-DE,en;q=0.1,fr;q=0.9")).to eq :fr
  end

  # `sort_by` is not stable in Ruby, so ordering by q-value alone lets two
  # implicit q=1.0 tags scramble.
  it "keeps header order when q-values tie" do
    expect(best("en,fr")).to eq :en
    expect(best("fr,en")).to eq :fr
  end

  # "fry" is West Frisian, not French.
  it "does not match a two-letter run inside a longer subtag" do
    expect(best("fry")).to be_nil
  end

  # RFC 9110: q=0 means "not acceptable", not "least preferred".
  it "never selects a language the visitor rejected with q=0" do
    expect(best("de;q=1,en;q=0")).to be_nil
  end

  it "ignores a tag whose weight is malformed rather than treating it as q=1" do
    expect(best("en;q=abc")).to be_nil
  end

  it "ignores a weight outside the 0-1 range" do
    expect(best("en;q=7")).to be_nil
  end

  it "still accepts a well-formed weight of every allowed shape" do
    expect(best("en;q=1.000")).to eq :en
    expect(best("en;q=0.001")).to eq :en
    expect(best("en; q=0.5")).to eq :en
  end
end
