# frozen_string_literal: true

require "rails_helper"

RSpec.describe ErrorPages::Locale do
  def resolve(env = {})
    described_class.new(ActionDispatch::TestRequest.create(env)).resolve
  end

  it "falls back to the default locale when the request says nothing" do
    expect(resolve).to eq :fr
  end

  it "reads the locale from the original path of the failed request" do
    expect(resolve("action_dispatch.original_path" => "/en/cups/2026")).to eq :en
  end

  it "ignores an original path whose first segment is not an available locale" do
    expect(resolve("action_dispatch.original_path" => "/de/cups/2026")).to eq :fr
  end

  it "prefers the failed request's path over Accept-Language" do
    expect(
      resolve("action_dispatch.original_path" => "/fr/x", "HTTP_ACCEPT_LANGUAGE" => "en-GB,en;q=0.9")
    ).to eq :fr
  end

  it "falls back to Accept-Language when the path carries no locale" do
    expect(resolve("HTTP_ACCEPT_LANGUAGE" => "en-GB,en;q=0.9")).to eq :en
  end

  it "skips unavailable languages in Accept-Language" do
    expect(resolve("HTTP_ACCEPT_LANGUAGE" => "de-DE,de;q=0.9,en;q=0.8")).to eq :en
  end

  # RFC 9110 language tags are case-insensitive.
  it "matches Accept-Language regardless of case" do
    expect(resolve("HTTP_ACCEPT_LANGUAGE" => "EN-US,EN;q=0.9")).to eq :en
  end

  # Header order is not preference order, and both locales are available here,
  # so reading the header left to right would pick the one deprioritised 9:1.
  it "honours q-values rather than header order" do
    expect(resolve("HTTP_ACCEPT_LANGUAGE" => "de-DE,en;q=0.1,fr;q=0.9")).to eq :fr
  end

  it "keeps header order when q-values tie" do
    expect(resolve("HTTP_ACCEPT_LANGUAGE" => "en,fr")).to eq :en
  end

  # "fry" is West Frisian, not French.
  it "does not match a two-letter run inside a longer subtag" do
    expect(resolve("HTTP_ACCEPT_LANGUAGE" => "fry")).to eq :fr
  end

  # RFC 9110: q=0 means "not acceptable", not "least preferred".
  it "never selects a language the visitor rejected with q=0" do
    expect(resolve("HTTP_ACCEPT_LANGUAGE" => "de;q=1,en;q=0")).to eq :fr
  end

  it "ignores a tag whose weight is malformed rather than treating it as q=1" do
    expect(resolve("HTTP_ACCEPT_LANGUAGE" => "en;q=abc")).to eq :fr
  end

  it "ignores a weight outside the 0-1 range" do
    expect(resolve("HTTP_ACCEPT_LANGUAGE" => "en;q=7")).to eq :fr
  end

  it "still accepts a well-formed weight of every allowed shape" do
    expect(resolve("HTTP_ACCEPT_LANGUAGE" => "en;q=1.000")).to eq :en
    expect(resolve("HTTP_ACCEPT_LANGUAGE" => "en;q=0.001")).to eq :en
    expect(resolve("HTTP_ACCEPT_LANGUAGE" => "en; q=0.5")).to eq :en
  end

  it "lets an explicit ?locale= override the path, so the pages can be previewed" do
    expect(resolve("action_dispatch.original_path" => "/fr/x", "QUERY_STRING" => "locale=en")).to eq :en
  end

  it "ignores an unavailable ?locale=" do
    expect(resolve("QUERY_STRING" => "locale=de")).to eq :fr
  end

  # A malformed query string is itself a 400: Request#GET re-raises it as
  # ActionController::BadRequest. Parsing it again here would raise inside the
  # error page and drop the visitor to Rails' plain-text failsafe.
  it "does not raise when the query string cannot be parsed" do
    expect(resolve("QUERY_STRING" => "locale=%")).to eq :fr
  end

  it "ignores a ?locale= that is not a string" do
    expect(resolve("QUERY_STRING" => "locale[]=en")).to eq :fr
  end
end
