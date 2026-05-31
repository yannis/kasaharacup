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

  def capture_sql(&block)
    queries = []
    subscriber = lambda do |_name, _start, _finish, _id, payload|
      next if payload[:name] == "SCHEMA"
      next if payload[:sql].match?(/\A\s*(BEGIN|COMMIT|ROLLBACK|SAVEPOINT|RELEASE)/i)

      queries << payload[:sql]
    end
    ActiveSupport::Notifications.subscribed(subscriber, "sql.active_record", &block)
    queries
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

  it "renders every pool without per-pool fight queries or per-fighter name lookups" do
    [1, 2].each do |pool|
      k1 = add_kenshi(pool: pool, position: 1)
      k2 = add_kenshi(pool: pool, position: 2)
      create(:fight, :pool_fight, individual_category: category, pool_number: pool,
        fighter_1: k1, fighter_2: k2)
    end

    queries = capture_sql do
      category.pools.sort_by(&:number).each do |pool|
        render_inline(described_class.new(category: category, pool_number: pool.number, admin: true))
      end
    end

    # The per-fighter namesake check (Kenshi#poster_name) and the per-pool fight
    # query (pool_number = N) are both gone — batched/shared on the category.
    expect(queries.grep(/SELECT 1 AS one FROM .kenshis./)).to be_empty
    expect(queries.grep(/FROM .fights.+"pool_number" = /)).to be_empty
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
