# frozen_string_literal: true

require "rails_helper"

describe Kenshis::CalculatePurchasesService do
  let(:cup) { create(:cup, :with_cup_products) }
  let(:team_category) { create(:team_category, cup: cup) }
  let(:individual_category) { create(:individual_category, cup: cup) }
  let(:product) { create(:product, cup: cup) }
  let!(:kenshi) { create(:kenshi, cup: cup, purchases: build_list(:purchase, 1, product: product)) }
  let(:service) { described_class.new(kenshi: kenshi) }

  # call is called in after_commit callback of kenshi
  # and kenhsi is touched in after_commit callback of purchase
  describe "#call" do
    context "when kenshi participates to TeamCategory" do
      before do
        create(:participation, kenshi: kenshi, category: create(:team_category, cup: cup))
        kenshi.purchases.destroy_all
      end

      it do
        expect { service.call }.to change { kenshi.purchases.count }.by(1)
        expect(kenshi.purchases.first.product).to eql cup.product_team
      end
    end

    context "when kenshi participates to IndividualCategory" do
      before do
        create(:participation, kenshi: kenshi, category: create(:individual_category, cup: cup))
        kenshi.purchases.destroy_all
      end

      it do
        expect { service.call }.to change { kenshi.purchases.count }.by(1)
        expect(kenshi.purchases.first.product).to eql cup.product_individual_adult
      end
    end

    context "when kenshi participates to TeamCategory and IndividualCategory" do
      before do
        create(:participation, kenshi: kenshi, category: create(:team_category, cup: cup))
        create(:participation, kenshi: kenshi, category: create(:individual_category, cup: cup))
        kenshi.purchases.destroy_all
      end

      it do
        expect { service.call }.to change { kenshi.purchases.count }.by(1)
        expect(kenshi.purchases.first.product).to eql cup.product_full_adult
      end

      context "when a participation is removed" do
        before do
          kenshi.participations.first.destroy
        end

        it do
          expect(kenshi.purchases.count).to eq(1)
          expect(kenshi.purchases.reload.first.product).to eql cup.product_individual_adult
        end
      end
    end
  end
end
