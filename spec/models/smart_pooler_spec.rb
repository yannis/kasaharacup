# frozen_string_literal: true

require "rails_helper"

RSpec.describe SmartPooler do
  let!(:cup) { create(:cup) }
  let(:smart_pooler) {
    described_class.new(individual_category)
  }
  let!(:individual_category) {
    create(:individual_category, name: "open", pool_size: 3, out_of_pool: 2, cup: cup)
  }

  24.times do |i|
    let!("participation#{i + 1}") {
      begin
        kenshi = create(:kenshi, cup: cup)
      rescue
        Rails.logger.info("retries to create kenshi: SmartPooler spec, line 14")
        retry
      end
      create(:participation, category: individual_category, kenshi: kenshi)
    }
  end

  before { smart_pooler.set_pools }

  it { expect(individual_category.pools.size).to eq 8 }
  it { expect(individual_category.tree).to be_a Tree }
  it { expect(individual_category.data).to be_a Hash }
  it { expect(individual_category.data.keys).to eq [:tree] }
  it { expect(individual_category.data[:tree].keys).to eq [:elements, :depth, :branch_number] }
end
