require 'spec_helper'

describe "A smart pooler" do
  let(:cup) {create :cup, start_on: "2016-09-28"}
  let(:individual_category) {create :individual_category, name: 'open', pool_size: 3, out_of_pool: 2, cup: cup}

  24.times do |i|
    let!("participation#{i+1}"){
      create :participation, category: individual_category, kenshi: create(:kenshi, cup: cup)
    }
  end

  let(:smart_pooler) {
    SmartPooler.new(individual_category)
  }

  before {smart_pooler.set_pools}

  it {expect(individual_category.pools.size).to eq 8}
  it {expect(individual_category.tree).to be_a Tree}
  it {expect(individual_category.data).to be_a Hash}
  it {expect(individual_category.data.keys).to eq [:tree]}
  it {expect(individual_category.data[:tree].keys).to eq [:elements, :depth, :branch_number]}
end
