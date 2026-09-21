# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Admin individual pool memberships" do
  let(:cup) { create(:cup) }
  let(:category) { create(:individual_category, cup: cup, pool_size: 3, out_of_pool: 2) }
  let(:admin) { create(:user, :admin) }

  before { sign_in admin }

  def member_in(pool, position, **attrs)
    create(:participation, category: category, kenshi: create(:kenshi, cup: cup),
      pool_number: pool, pool_position: position, **attrs)
  end

  def unpooled_member
    create(:participation, category: category, kenshi: create(:kenshi, cup: cup), pool_number: nil)
  end

  def tree_stream = Turbo::StreamsChannel.send(:stream_name_from, [category, :competition_tree])

  def move(participation, to_pool, **params)
    patch admin_individual_category_pool_membership_path(category, participation),
      params: {to_pool_number: to_pool, **params},
      as: :turbo_stream
  end

  it "moves a member and replaces both pool cards" do
    member_in(1, 1)
    b = member_in(1, 2)
    member_in(2, 1)

    move(b, 2)

    expect(response).to have_http_status(:ok)
    expect(b.reload.pool_number).to eq 2
    expect(response.body).to include("target=\"#{ActionView::RecordIdentifier.dom_id(category, "pool_1")}\"")
    expect(response.body).to include("target=\"#{ActionView::RecordIdentifier.dom_id(category, "pool_2")}\"")
  end

  it "removes the source pool card when the move empties it" do
    lonely = member_in(1, 1)
    member_in(2, 1)

    move(lonely, 2)

    expect(response.body).to include(
      "turbo-stream action=\"remove\" target=\"#{ActionView::RecordIdentifier.dom_id(category, "pool_1")}\""
    )
  end

  it "answers 422 with a message when the move is destructive and unforced" do
    member_in(1, 1)
    b = member_in(1, 2)
    member_in(1, 3)
    member_in(2, 1)
    PoolFightGenerator.new(category).call
    category.pool_fights.where(pool_number: 1).first.update_column(:draw, true)

    move(b, 2)

    expect(response).to have_http_status(:unprocessable_content)
    expect(response.parsed_body["message"]).to be_present
    expect(b.reload.pool_number).to eq 1
  end

  it "performs the destructive move when forced (the JS confirm-retry path)" do
    member_in(1, 1)
    b = member_in(1, 2)
    member_in(1, 3)
    member_in(2, 1)
    PoolFightGenerator.new(category).call
    category.pool_fights.where(pool_number: 1).first.update_column(:draw, true)

    move(b, 2, force: true)

    expect(response).to have_http_status(:ok)
    expect(b.reload.pool_number).to eq 2
  end

  it "un-pools a member when the destination is blank, refreshing the unpooled panel" do
    member_in(1, 1)
    b = member_in(1, 2)

    move(b, "")

    expect(response).to have_http_status(:ok)
    expect(b.reload.pool_number).to be_nil
    expect(response.body).to include("target=\"individual_pool_unpooled_#{category.id}\"")
  end

  it "creates a new pool by replacing the pools container (idempotent — no double-apply on the acting admin)" do
    member_in(1, 1)
    member_in(1, 2)
    late = unpooled_member

    move(late, 2)

    expect(response).to have_http_status(:ok)
    expect(late.reload.pool_number).to eq 2
    expect(response.body).to include(
      "turbo-stream action=\"replace\" target=\"individual_pools_#{category.id}\""
    )
    expect(response.body).not_to include("action=\"append\"")
  end

  # The team sibling's spec explains both guards; the individual side is held
  # to the same two.
  it "broadcasts exactly the streams it renders" do
    member_in(1, 1)
    b = member_in(1, 2)
    member_in(2, 1)

    expect { move(b, 2) }
      .to have_broadcasted_to(tree_stream)
        .from_channel(Turbo::StreamsChannel)
        .with { |payload| expect(payload).to eq response.body }
  end

  it "renders the unpooled panel once when moving between existing pools" do
    member_in(1, 1)
    b = member_in(1, 2)
    member_in(2, 1)
    unpooled_member

    renders = count_renders { move(b, 2) }

    expect(response).to have_http_status(:ok)
    expect(renders.count("IndividualPoolUnpooledComponent")).to eq 1
  end

  it "renders the pools container once when the move creates a pool" do
    member_in(1, 1)
    member_in(1, 2)
    late = unpooled_member

    renders = count_renders { move(late, 2) }

    expect(response).to have_http_status(:ok)
    expect(renders.count("admin/individual_categories/pools")).to eq 1
  end

  it "renders the bracket tree once when the move clears it" do
    member_in(1, 1, rank: 1)
    member_in(1, 2, rank: 2)
    b = member_in(1, 3, rank: 3)
    member_in(2, 1, rank: 1)
    member_in(2, 2, rank: 2)
    IndividualCategoryBracketBuilder.new(category).call

    renders = count_renders { move(b, 2, force: true) }

    expect(response).to have_http_status(:ok)
    expect(renders.count("CompetitionTreeComponent")).to eq 1
  end

  it "redirects non-admins away" do
    sign_out admin
    sign_in create(:user)
    member_in(1, 1)
    b = member_in(1, 2)

    move(b, 2)

    expect(response).to redirect_to(root_url)
    expect(b.reload.pool_number).to eq 1
  end
end
