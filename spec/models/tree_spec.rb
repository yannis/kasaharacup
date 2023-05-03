# frozen_string_literal: true

require "rails_helper"

RSpec.describe Tree do
  context "A open category with 24 kenshis" do
    let!(:cup) { create(:cup, start_on: Date.parse("2022-09-28")) }
    let!(:category) { create(:individual_category, name: "open", pool_size: 3, cup: cup, out_of_pool: 2) }
    let(:tree) { category.tree }
    let(:elements) { tree.elements }

    before do
      25.times do |i|
        create(:kenshi,
          first_name: "kenshi_#{i}",
          cup: cup,
          participations: build_list(:participation, 1, category: category))
      end
    end

    it do
      expect(category.participations.count).to eq 25
      expect(tree.branch_number).to eq 0
      expect(tree.depth).to eq 0
      expect(elements.first).to be_nil
    end

    context "when pools are generated" do
      before { category.set_smart_pools }

      it do
        expect(tree.branch_number).to eq 20
        expect(tree.depth).to eq 4
        expect(elements.first).to be_a String
      end
    end
  end
end
