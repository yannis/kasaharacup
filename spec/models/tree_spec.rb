# frozen_string_literal: true

require "rails_helper"

RSpec.describe Tree, type: :model do
  context "A open category with 24 kenshis" do
    let!(:cup) { create :cup, start_on: Date.parse("2022-09-28") }
    let!(:open) { create :individual_category, name: "open", pool_size: 3, cup: cup, out_of_pool: 2 }
    let(:tree) { open.tree }
    let(:elements) { tree.elements }

    before do
      # rubocop:disable RSpec/FactoryBot/CreateList
      25.times { create :participation, category: open, kenshi: build(:kenshi, cup: cup) }
      # rubocop:enable RSpec/FactoryBot/CreateList
    end

    it { expect(open.participations.count).to eq 25 }
    it { expect(tree.branch_number).to eq 0 }
    it { expect(tree.depth).to eq 0 }
    it { expect(elements.first).to be nil }

    context "when pools are generated" do
      before { open.set_smart_pools }

      it { expect(tree.branch_number).to eq 20 }
      it { expect(tree.depth).to eq 4 }
      it { expect(elements.first).to be_a String }
    end
  end
end
