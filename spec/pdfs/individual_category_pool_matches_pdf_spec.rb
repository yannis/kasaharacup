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

    names = texts_in(described_class.new(category)).select { |text| text.start_with?("TANAKA") }

    expect(names).to all(eq("TANAKA"))
    expect(names.size).to eq 2
  end

  it "tells two namesakes of the same pool apart" do
    qualify(create(:kenshi, cup: cup, first_name: "Akira", last_name: "Sato"))
    qualify(create(:kenshi, cup: cup, first_name: "Botan", last_name: "Sato"))

    names = texts_in(described_class.new(category)).select { |text| text.start_with?("SATO") }.uniq

    expect(names).to contain_exactly("SATO A.", "SATO B.")
  end
end
