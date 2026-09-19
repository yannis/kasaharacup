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
    expect(response.body).to include("target=\"individual_seeds_#{category.id}\"")
    expect(response.body).to include("target=\"individual_pools_#{category.id}\"")
  end

  # The panel's JavaScript refuses to send a blank position, but that guarantee
  # lives a layer away from this contract: a direct caller gets the unseed the
  # service defines for a blank target.
  it "treats an update with a blank position as an unseed" do
    seeded = participant(seed: 1)

    move(seeded, "")

    expect(response).to have_http_status(:ok)
    expect(seeded.reload.seed).to be_nil
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

  it "redirects a non-admin away" do
    sign_in create(:user)
    seeded = participant(seed: 1)

    move(seeded, 1)

    expect(response).to redirect_to(root_url)
    expect(seeded.reload.seed).to eq 1
  end

  describe "a position that is not a position" do
    # "abc".to_i is 0, which used to clamp to 1 and silently make the
    # participant the TOP seed — the most valuable slot in the panel handed
    # out by a stale client sending "undefined".
    it "refuses a non-numeric position rather than reading it as 1" do
      a = participant(seed: 1)
      b = participant(seed: 2)

      move(b, "abc")

      expect(response).to have_http_status(:bad_request)
      expect([a.reload.seed, b.reload.seed]).to eq [1, 2]
    end

    it "refuses a zero or negative position" do
      participant(seed: 1)
      b = participant(seed: 2)

      move(b, "0")

      expect(response).to have_http_status(:bad_request)
      expect(b.reload.seed).to eq 2
    end

    # A non-scalar used to reach Integer#to_i on an Array and raise a 500.
    it "refuses a non-scalar position" do
      b = participant(seed: 1)

      patch admin_individual_category_seed_path(category, b),
        params: {to_position: ["1"]}, as: :turbo_stream

      expect(response).to have_http_status(:bad_request)
      expect(b.reload.seed).to eq 1
    end
  end

  # The per-row select offers the row's own current position, so this is one
  # mis-click away at all times. Re-rendering the panel, every pool card and the
  # whole tree — and broadcasting them — to say nothing changed is pure waste.
  it "answers a move that changes nothing with no content" do
    participant(seed: 1)
    b = participant(seed: 2)

    move(b, 2)

    expect(response).to have_http_status(:no_content)
    expect(b.reload.seed).to eq 2
  end

  # The unseed control is a plain button_to, so a browser that never ran Turbo
  # has to get a page back rather than raw <turbo-stream> markup.
  it "redirects to the category when the request is not a turbo stream" do
    seeded = participant(seed: 1)

    delete admin_individual_category_seed_path(category, seeded)

    expect(response).to redirect_to(admin_individual_category_path(category))
    expect(seeded.reload.seed).to be_nil
  end

  # A category edit can invalidate a participation that is already seeded
  # (narrowing max_age under a seeded kenshi). Renumbering must not run that
  # record's own validations, or seeding dies for the whole category.
  it "still reorders when an already seeded participation is now invalid" do
    a = participant(seed: 1)
    b = participant(seed: 2)
    category.update_columns(max_age: a.kenshi.age_at_cup - 1)

    move(b, 1)

    expect(response).to have_http_status(:success)
    expect([a.reload.seed, b.reload.seed]).to eq [2, 1]
  end
end
