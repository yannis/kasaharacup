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

  it "renders a generate button when no fights exist" do
    add_kenshi(pool: 1, position: 1)
    add_kenshi(pool: 1, position: 2)

    rendered = render_inline(described_class.new(category: category, pool_number: 1, admin: true))

    expect(rendered.to_html).to include("Generate pool fights")
  end

  it "renders the matches list and standings" do
    k1 = add_kenshi(pool: 1, position: 1)
    k2 = add_kenshi(pool: 1, position: 2)
    create(:fight, :pool_fight, individual_category: category, pool_number: 1,
      fighter_1: k1, fighter_2: k2)

    rendered = render_inline(described_class.new(category: category, pool_number: 1, admin: true))

    expect(rendered.to_html).to include("Match 1")
    expect(rendered.to_html).to include("Reset this pool's fights")
    expect(rendered.css("table.pool-standings").size).to eq 1
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
