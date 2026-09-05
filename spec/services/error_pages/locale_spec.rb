# frozen_string_literal: true

require "rails_helper"

RSpec.describe ErrorPages::Locale do
  def resolve(env = {})
    described_class.new(ActionDispatch::TestRequest.create(env)).to_sym
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

  it "falls back to Accept-Language when the path carries no locale" do
    expect(resolve("HTTP_ACCEPT_LANGUAGE" => "en-GB,en;q=0.9")).to eq :en
  end

  it "skips unavailable languages in Accept-Language" do
    expect(resolve("HTTP_ACCEPT_LANGUAGE" => "de-DE,de;q=0.9,en;q=0.8")).to eq :en
  end

  it "lets an explicit ?locale= override the path, so the pages can be previewed" do
    expect(resolve("action_dispatch.original_path" => "/fr/x", "QUERY_STRING" => "locale=en")).to eq :en
  end

  it "ignores an unavailable ?locale=" do
    expect(resolve("QUERY_STRING" => "locale=de")).to eq :fr
  end

  # A malformed query string is itself a 400. Parsing it again here would raise
  # inside the error page and drop the visitor to Rails' plain-text failsafe.
  it "does not raise when the query string cannot be parsed" do
    request = ActionDispatch::TestRequest.create
    allow(request).to receive(:GET).and_raise(Rack::QueryParser::ParameterTypeError)

    expect(described_class.new(request).to_sym).to eq :fr
  end
end
