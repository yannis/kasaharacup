# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Admin individual seeds" do
  let(:cup) { create(:cup) }
  let(:category) { create(:individual_category, cup: cup, pool_size: 3, out_of_pool: 2) }
  let(:admin) { create(:user, :admin) }
  let(:sequence) { (1..).each }

  before { sign_in admin }

  def participant(seed: nil, pool: nil, position: nil)
    n = sequence.next
    kenshi = create(:kenshi, cup: cup, first_name: "First#{n}", last_name: "Last#{n}")
    create(:participation, category: category, kenshi: kenshi, seed: seed,
      pool_number: pool, pool_position: position)
  end

  def move(participation, to_position)
    patch admin_individual_category_seed_path(category, participation),
      params: {to_position: to_position}, as: :turbo_stream
  end

  def unseed(participation)
    delete admin_individual_category_seed_path(category, participation), as: :turbo_stream
  end

  it "seeds a participant and replaces the panel" do
    fresh = participant

    move(fresh, 1)

    expect(response).to have_http_status(:ok)
    expect(fresh.reload.seed).to eq 1
    expect(response.body).to include("target=\"individual_seeds_#{category.id}\"")
  end

  it "reorders and renumbers the list" do
    first = participant(seed: 1)
    second = participant(seed: 2)

    move(second, 1)

    expect(second.reload.seed).to eq 1
    expect(first.reload.seed).to eq 2
  end

  it "unseeds on destroy and closes the gap" do
    first = participant(seed: 1)
    second = participant(seed: 2)

    unseed(first)

    expect(response).to have_http_status(:ok)
    expect(first.reload.seed).to be_nil
    expect(second.reload.seed).to eq 1
  end

  # A seeded participant already in a pool wears its badge on the pool card,
  # which would otherwise keep the old number until a full page load.
  it "replaces the pools container so the badges cannot go stale" do
    pooled = participant(pool: 1, position: 1)
    participant(pool: 1, position: 2)

    move(pooled, 1)

    expect(response.body).to include("target=\"individual_pools_#{category.id}\"")
  end

  it "replaces the competition tree when one exists" do
    a = participant(pool: 1, position: 1)
    participant(pool: 1, position: 2)
    participant(pool: 2, position: 1)
    participant(pool: 2, position: 2)
    category.participations.each_with_index { |p, i| p.update!(pool_rank: (i % 2) + 1) }
    IndividualCategoryBracketBuilder.new(category).call

    move(a, 1)

    expect(response.body).to include(
      "target=\"#{ActionView::RecordIdentifier.dom_id(category, :competition_tree)}\""
    )
  end

  it "leaves the tree alone when there is none" do
    fresh = participant

    move(fresh, 1)

    expect(response.body).not_to include(
      "target=\"#{ActionView::RecordIdentifier.dom_id(category, :competition_tree)}\""
    )
  end

  # The scoped lookup does raise ActiveRecord::RecordNotFound, but
  # config/environments/test.rb sets show_exceptions to :rescuable: a
  # rescuable exception (RecordNotFound has a default 404 mapping) renders
  # the debug exception page with that status instead of propagating to the
  # spec, so this asserts the response rather than a raised error.
  it "refuses a participation from another category" do
    other = create(:individual_category, cup: cup, pool_size: 3)
    stranger = create(:participation, category: other, kenshi: create(:kenshi, cup: cup))

    move(stranger, 1)

    expect(response).to have_http_status(:not_found)
  end
end
