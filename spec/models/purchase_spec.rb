# frozen_string_literal: true

require "rails_helper"

RSpec.describe Purchase, type: :model do
  describe "Associations" do
    let(:purchase) { build(:purchase) }

    it do
      expect(purchase).to belong_to :kenshi
      expect(purchase).to belong_to :product
    end
  end

  describe "Validations" do
    describe "#in_quota" do
      let!(:product) { create(:product, quota: 3, cup: create(:cup)) }
      let(:purchase) { build(:purchase, product: product) }

      context "when purchase quota is not reached" do
        before { create_list(:purchase, 2, product: product) }

        it { expect(purchase).to be_valid }
      end

      context "when purchase quota is reached" do
        before { create_list(:purchase, 3, product: product) }

        it do
          expect(purchase).not_to be_valid
          expect(purchase.errors.full_messages)
            .to contain_exactly("Product ce produit n'est malheureusement plus disponible")
        end
      end
    end
  end

  describe "#descriptive_name" do
    let(:purchase) { build(:purchase, product: product) }
    let(:product) { build(:product, name_en: "Saturday dinner", name_fr: "Dîner du samedi", fee_chf: 8, fee_eu: 10) }

    it { expect(purchase.descriptive_name).to eq("Dîner du samedi (8 CHF / 10 €)") }
  end
end
