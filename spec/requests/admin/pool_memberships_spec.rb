# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Admin pool memberships" do
  let(:cup) { create(:cup) }
  let(:tc) { create(:team_category, cup: cup, pool_size: 3, out_of_pool: 2, team_size: 3) }
  let(:admin) { create(:user, :admin) }

  before { sign_in admin }

  def team_in(pool, position)
    create(:team, team_category: tc, pool_number: pool, pool_position: position)
  end

  def move(team, to_pool, **params)
    patch admin_team_category_pool_membership_path(tc, team),
      params: {to_pool_number: to_pool, **params},
      as: :turbo_stream
  end

  it "moves a team and replaces both pool cards" do
    team_in(1, 1)
    b = team_in(1, 2)
    team_in(2, 1)

    move(b, 2)

    expect(response).to have_http_status(:ok)
    expect(b.reload.pool_number).to eq 2
    expect(response.body).to include("turbo-stream action=\"replace\" target=\"team_pool_#{tc.id}_1\"")
    expect(response.body).to include("turbo-stream action=\"replace\" target=\"team_pool_#{tc.id}_2\"")
  end

  it "removes the source pool card when the move empties it" do
    lonely = team_in(1, 1)
    team_in(2, 1)

    move(lonely, 2)

    expect(response.body).to include("turbo-stream action=\"remove\" target=\"team_pool_#{tc.id}_1\"")
  end

  it "answers 422 with a message when the move is destructive and unforced" do
    team_in(1, 1)
    b = team_in(1, 2)
    team_in(1, 3)
    team_in(2, 1)
    PoolEncounterGenerator.new(tc).call
    tc.encounters.where(pool_number: 1).first.update!(lineup_1_set: true)

    move(b, 2)

    expect(response).to have_http_status(:unprocessable_content)
    expect(response.parsed_body["message"]).to be_present
    expect(b.reload.pool_number).to eq 1
  end

  it "performs the destructive move when forced" do
    team_in(1, 1)
    b = team_in(1, 2)
    team_in(1, 3)
    team_in(2, 1)
    PoolEncounterGenerator.new(tc).call
    tc.encounters.where(pool_number: 1).first.update!(lineup_1_set: true)

    move(b, 2, force: true)

    expect(response).to have_http_status(:ok)
    expect(b.reload.pool_number).to eq 2
  end

  it "adds an unpooled team to an existing pool and refreshes the unpooled panel" do
    team_in(1, 1)
    team_in(1, 2)
    late = create(:team, team_category: tc, pool_number: nil)

    move(late, 1)

    expect(response).to have_http_status(:ok)
    expect(late.reload.pool_number).to eq 1
    expect(response.body).to include("turbo-stream action=\"replace\" target=\"team_pool_#{tc.id}_1\"")
    expect(response.body).to include("turbo-stream action=\"replace\" target=\"team_pool_unpooled_#{tc.id}\"")
  end

  it "creates a new pool by replacing the pools container (idempotent — no double-apply on the acting admin)" do
    team_in(1, 1)
    team_in(1, 2)
    late = create(:team, team_category: tc, pool_number: nil)

    move(late, 2)

    expect(response).to have_http_status(:ok)
    expect(late.reload.pool_number).to eq 2
    expect(response.body).to include("turbo-stream action=\"replace\" target=\"team_pools_#{tc.id}\"")
    expect(response.body).not_to include("action=\"append\"")
  end

  it "un-pools a team when the destination is blank, refreshing the source and unpooled panel" do
    team_in(1, 1)
    b = team_in(1, 2)

    move(b, "")

    expect(response).to have_http_status(:ok)
    expect(b.reload.pool_number).to be_nil
    expect(response.body).to include("turbo-stream action=\"replace\" target=\"team_pool_unpooled_#{tc.id}\"")
    # no destination pool card stream (there is no destination pool)
    expect(response.body).not_to include("target=\"team_pool_#{tc.id}_\"")
  end

  it "redirects non-admins away" do
    sign_out admin
    sign_in create(:user)
    team_in(1, 1)
    b = team_in(1, 2)

    move(b, 2)

    expect(response).to redirect_to(root_url)
    expect(b.reload.pool_number).to eq 1
  end
end
