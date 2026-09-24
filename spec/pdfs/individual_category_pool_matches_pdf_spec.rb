# frozen_string_literal: true

require "rails_helper"

RSpec.describe IndividualCategoryPoolMatchesPdf do
  let(:cup) { create(:cup) }
  let(:category) { create(:individual_category, cup: cup, pool_size: 3) }

  def qualify(kenshi, in_category: category)
    create(:participation, category: in_category, kenshi: kenshi, pool_number: 1)
    kenshi
  end

  it "spells a fighter the same way in the match grid and in the standings" do
    # A namesake this category never meets: scoping the two tables differently
    # would initial one of them and not the other.
    qualify(create(:kenshi, cup: cup, first_name: "Akira", last_name: "Tanaka"))
    qualify(create(:kenshi, cup: cup, first_name: "Botan", last_name: "Tanaka"),
      in_category: create(:individual_category, cup: cup, pool_size: 3))
    qualify(create(:kenshi, cup: cup, first_name: "Chika", last_name: "Yamada"))

    PoolFightGenerator.new(category).call
    names = texts_in(described_class.new(category)).select { |text| text.start_with?("TANAKA") }

    expect(names).to all(eq("TANAKA"))
    expect(names.size).to eq 2
  end

  it "tells two namesakes of the same pool apart" do
    qualify(create(:kenshi, cup: cup, first_name: "Akira", last_name: "Sato"))
    qualify(create(:kenshi, cup: cup, first_name: "Botan", last_name: "Sato"))

    PoolFightGenerator.new(category).call
    names = texts_in(described_class.new(category)).select { |text| text.start_with?("SATO") }.uniq

    expect(names).to contain_exactly("SATO A.", "SATO B.")
  end

  it "prints the pool's fights in their order, white on the left and red on the right" do
    first, second, third = %w[Alpha Bravo Charlie].each_with_index.map do |name, index|
      kenshi = create(:kenshi, cup: cup, last_name: name)
      create(:participation, category: category, kenshi: kenshi, pool_number: 1, pool_position: index + 1)
      kenshi
    end
    PoolFightGenerator.new(category).call

    rows = texts_in(described_class.new(category)).each_cons(4)
      .filter_map { |number, white, _x, red| [number, white, red] if number.match?(/\A\d\.\z/) }

    # Red is fighter_1: the pool's first fighter, and a fighter fighting twice
    # in a row keeps its side. The standings below repeat the names.
    expect(rows).to eq [["1.", second, first], ["2.", third, first], ["3.", third, second]]
      .map { |number, white, red| [number, white.last_name.upcase, red.last_name.upcase] }
  end
end
