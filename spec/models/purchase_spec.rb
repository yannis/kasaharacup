# frozen_string_literal: true

require "rails_helper"

RSpec.describe Purchase do
  describe "Associations" do
    let(:purchase) { build(:purchase) }

    it do
      expect(purchase).to belong_to :kenshi
      expect(purchase).to belong_to :product
    end
  end

  describe "Validations" do
    describe "#in_quota" do
      context "when product require_personal_infos" do
        let(:cup) { create(:cup) }
        let!(:product_1) { create(:product, cup: cup, quota: 3, require_personal_infos: true) }
        let!(:product_2) { create(:product, cup: cup, quota: 3, require_personal_infos: true) }
        let!(:kenshi) { create(:kenshi) }
        let(:purchase) { build(:purchase, product: product_1) }

        before do
          ENV["DORMITORY_QUOTA"] = "4"
          create(:purchase, product: product_1, kenshi: kenshi)
          create(:purchase, product: product_1)
        end

        after { ENV["DORMITORY_QUOTA"] = nil }

        context "when purchase quota is not reached" do
          before { create_list(:purchase, 1, product: product_2) }

          it { expect(purchase).to be_valid }
        end

        context "when purchase quota is reached" do
          context "when different kenshis bought the products" do
            before { create_list(:purchase, 2, product: product_2) }

            it do
              expect(purchase).not_to be_valid
              expect(purchase.errors.full_messages)
                .to contain_exactly("Product ce produit n'est malheureusement plus disponible")
            end
          end

          context "when same kenshi bought 2 different product" do
            before do
              create(:purchase, product: product_2, kenshi: kenshi)
              create(:purchase, product: product_2)
            end

            it { expect(purchase).to be_valid }
          end
        end
      end

      context "when product doesn't require_personal_infos" do
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
  end

  describe "#descriptive_name" do
    let(:purchase) { build(:purchase, product: product) }
    let(:product) { build(:product, name_en: "Saturday dinner", name_fr: "Dîner du samedi", fee_chf: 8, fee_eu: 10) }

    it { expect(purchase.descriptive_name).to eq("Dîner du samedi (8 CHF / 10 €)") }
  end
end
