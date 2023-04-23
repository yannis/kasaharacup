# frozen_string_literal: true

require "rails_helper"

RSpec.describe Pool do
  let(:individual_category) { create(:individual_category) }
  let(:participation1) {
    create(:participation, category: individual_category,
      kenshi: create(:kenshi, grade: "kyu", cup: individual_category.cup))
  }
  let(:participation2) {
    create(:participation, category: individual_category,
      kenshi: create(:kenshi, grade: "kyu", cup: individual_category.cup))
  }
  let(:participation3) {
    create(:participation, category: individual_category,
      kenshi: create(:kenshi, grade: "kyu", cup: individual_category.cup))
  }
  let(:pool) { described_class.new number: 3, participations: [participation1, participation2, participation3] }

  it { expect(pool).not_to be_contains_high_rank }

  context "with an high rank" do
    before { participation3.kenshi.update grade: "5Dan" }

    it { expect(pool).to be_contains_high_rank }
  end
end
