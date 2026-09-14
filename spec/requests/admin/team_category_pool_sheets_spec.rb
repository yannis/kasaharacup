# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Admin team category pool sheets" do
  let(:cup) { create(:cup) }
  let(:category) { create(:team_category, cup: cup, team_size: 3, pool_size: 2, out_of_pool: 1) }
  let(:admin) { create(:user, :admin) }

  before { sign_in admin }

  def fill_a_pool(number)
    2.times { |index| create(:team, team_category: category, pool_number: number, pool_position: index + 1) }
    PoolEncounterGenerator.new(category).call
  end

  it "sends the pool sheets as an inline PDF" do
    fill_a_pool(1)

    get pool_sheets_admin_team_category_path(category)

    expect(response).to have_http_status(:ok)
    expect(response.media_type).to eq "application/pdf"
    expect(response.headers["Content-Disposition"]).to include("inline")
    expect(response.body).to start_with("%PDF")
  end

  it "offers the sheets on a pooled category and withholds them from a bracket-only one" do
    fill_a_pool(1)
    bracket_only = create(:team_category, cup: cup, team_size: 3, pool_size: 1)

    get admin_team_category_path(category)
    expect(response.body).to include(pool_sheets_admin_team_category_path(category))

    get admin_team_category_path(bracket_only)
    expect(response.body).not_to include(pool_sheets_admin_team_category_path(bracket_only))
  end

  it "redirects a non-admin away" do
    fill_a_pool(1)
    sign_out admin
    sign_in create(:user)

    get pool_sheets_admin_team_category_path(category)

    expect(response).to have_http_status(:redirect)
  end

  # Uncached SELECTs: query-cache hits and schema lookups say nothing about how
  # a document scales.
  def count_selects
    count = 0
    subscriber = ActiveSupport::Notifications.subscribe("sql.active_record") do |_, _, _, _, payload|
      next if payload[:name] == "SCHEMA" || payload[:cached]

      count += 1
    end
    yield
    count
  ensure
    ActiveSupport::Notifications.unsubscribe(subscriber)
  end

  # The sheet prints every pool of the category, so it must read them together:
  # one more pool must not mean another round-trip for its ties and bouts.
  it "does not send more queries as the category gains pools" do
    2.times { |number| fill_a_pool(number + 1) }
    get pool_sheets_admin_team_category_path(category)
    small = count_selects { get pool_sheets_admin_team_category_path(category) }

    2.times { |number| fill_a_pool(number + 3) }
    large = count_selects { get pool_sheets_admin_team_category_path(category) }

    expect(large).to eq small
  end
end
