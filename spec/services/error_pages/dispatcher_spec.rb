# frozen_string_literal: true

require "rails_helper"

RSpec.describe ErrorPages::Dispatcher do
  let(:downstream) { ->(env) { [200, {}, [env["QUERY_STRING"].to_s]] } }
  let(:dispatcher) { described_class.new(downstream) }

  def query_string_seen_by(env)
    dispatcher.call(ActionDispatch::TestRequest.create(env).env).last.first
  end

  it "passes a parseable request through untouched" do
    expect(query_string_seen_by("QUERY_STRING" => "locale=en")).to eq "locale=en"
  end

  # Otherwise ActionController::Instrumentation re-parses it before the action
  # and ShowExceptions falls through to its plain-text failsafe.
  it "blanks a query string that cannot be parsed" do
    expect(query_string_seen_by("QUERY_STRING" => "locale=%")).to eq ""
  end

  it "blanks a query string whose parameter types conflict" do
    expect(query_string_seen_by("QUERY_STRING" => "a[]=1&a[b]=2")).to eq ""
  end

  # Rack::MethodOverride reads the body on the way down looking for _method,
  # swallows the parse error, and leaves the raw data cached in
  # rack.request.form_*. Rack re-parses from that cache in preference to
  # rack.input, so replacing the input alone achieves nothing — this is what
  # the real middleware stack does, and what a plain unit env does not.
  it "drops Rack's cached form data, not just the input" do
    env = ActionDispatch::TestRequest.create(
      "REQUEST_METHOD" => "POST",
      "CONTENT_TYPE" => "application/x-www-form-urlencoded",
      "rack.input" => StringIO.new("a[]=1&a[b]=2")
    ).env
    env["rack.request.form_vars"] = "a[]=1&a[b]=2"
    env["rack.request.form_pairs"] = [["a[]", "1"], ["a[b]", "2"]]

    seen = nil
    described_class.new(->(passed) { seen = passed; [200, {}, []] }).call(env)

    expect(seen.keys.grep(/\Arack\.request\.form_/)).to be_empty
    expect { ActionDispatch::Request.new(seen).POST }.not_to raise_error
  end

  it "blanks the parameters when the form body cannot be parsed" do
    env = ActionDispatch::TestRequest.create(
      "QUERY_STRING" => "locale=en",
      "REQUEST_METHOD" => "POST",
      "CONTENT_TYPE" => "application/x-www-form-urlencoded",
      "rack.input" => StringIO.new("a[]=1&a[b]=2")
    ).env

    status, _headers, body = dispatcher.call(env)

    expect(status).to eq 200
    expect(body.first).to eq ""
  end
end
