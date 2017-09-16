require 'rails_helper'

RSpec.describe ProductsHelper, type: :helper do
  let!(:cup){create :kendocup_cup, start_on: Date.current+20.days}
  let(:product) {create :kendocup_product, cup: cup, name_en: 'night at the dormitory'}
  let(:product2) {create :kendocup_product, cup: cup, name_en: 'another product' }

  context 'dormitory product' do
    context 'with 49 purchases' do
      before do
        allow_any_instance_of(Kendocup::Product).to receive(:purchases).and_return((0..48).to_a)
      end
      it { expect(product_available?(product)).to be true }
    end

    context 'with 50 purchases' do
      before do
        allow_any_instance_of(Kendocup::Product).to receive(:purchases).and_return((0..49).to_a)
      end
      it { expect(product_available?(product)).to be false }
    end
  end

  context 'another product' do
    context 'with 49 purchases' do
      before do
        allow_any_instance_of(Kendocup::Product).to receive(:purchases).and_return((0..48).to_a)
      end
      it { expect(product_available?(product2)).to be true }
    end

    context 'with 50 purchases' do
      before do
        allow_any_instance_of(Kendocup::Product).to receive(:purchases).and_return((0..49).to_a)
      end
      it { expect(product_available?(product2)).to be true }
    end
  end
end
