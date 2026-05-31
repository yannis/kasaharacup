# frozen_string_literal: true

require "rails_helper"

RSpec.describe PoolComponent, type: :component do
  let(:cup) { create(:cup) }
  let(:category) { create(:individual_category, cup: cup) }

  def add_kenshi(pool:, position:)
    kenshi = create(:kenshi, cup: cup)
    create(:participation, category: category, kenshi: kenshi,
      pool_number: pool, pool_position: position)
    kenshi
  end

  it "renders an empty-state message when no fights exist" do
    add_kenshi(pool: 1, position: 1)
    add_kenshi(pool: 1, position: 2)

    rendered = render_inline(described_class.new(category: category, pool_number: 1, admin: true))

    expect(rendered.to_html).to include("No pool fights yet.")
    expect(rendered.to_html).not_to include("Generate pool fights")
  end

  it "renders the matches list and standings" do
    k1 = add_kenshi(pool: 1, position: 1)
    k2 = add_kenshi(pool: 1, position: 2)
    create(:fight, :pool_fight, individual_category: category, pool_number: 1,
      fighter_1: k1, fighter_2: k2)

    rendered = render_inline(described_class.new(category: category, pool_number: 1, admin: true))

    expect(rendered.to_html).to include("Match 1")
    expect(rendered.to_html).to include("Regenerate this pool's fights")
    expect(rendered.css("table.pool-standings").size).to eq 1
  end

  it "renders a single editable Rank column instead of separate Suggested and Rank columns" do
    k1 = add_kenshi(pool: 1, position: 1)
    k2 = add_kenshi(pool: 1, position: 2)
    create(:fight, :pool_fight, individual_category: category, pool_number: 1,
      fighter_1: k1, fighter_2: k2, winner: k1)

    rendered = render_inline(described_class.new(category: category, pool_number: 1, admin: true))

    headers = rendered.css("table.pool-standings thead th").map(&:text)
    expect(headers).to include("Rank")
    expect(headers).not_to include("Suggested")
    # One editable pool_rank cell per fighter, showing the recomputed rank.
    editable = rendered.css(".pool-standings__rank .pool-standings__editable")
    expect(editable.size).to eq 2
    expect(editable.map { |cell| cell.text.strip }).to contain_exactly("1", "2")
  end

  it "flags genuinely tied fighters with an = hint" do
    k1 = add_kenshi(pool: 1, position: 1)
    k2 = add_kenshi(pool: 1, position: 2)
    create(:fight, :pool_fight, individual_category: category, pool_number: 1,
      fighter_1: k1, fighter_2: k2, draw: true)

    rendered = render_inline(described_class.new(category: category, pool_number: 1, admin: true))

    expect(rendered.css(".pool-standings__rank .pool-standings__tie").size).to eq 2
  end

  it "labels tiebreakers separately" do
    k1 = add_kenshi(pool: 1, position: 1)
    k2 = add_kenshi(pool: 1, position: 2)
    create(:fight, :pool_fight, individual_category: category, pool_number: 1,
      fighter_1: k1, fighter_2: k2)
    create(:fight, :tiebreaker, individual_category: category, pool_number: 1,
      fighter_1: k1, fighter_2: k2)

    rendered = render_inline(described_class.new(category: category, pool_number: 1, admin: true))

    expect(rendered.to_html).to include("Tiebreaker —")
  end
end
