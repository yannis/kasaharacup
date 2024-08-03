# frozen_string_literal: true

require "rails_helper"

RSpec.describe Product do
  describe "Attributes" do
    let(:cup) { create(:cup) }
    let(:product) { build(:product, cup: cup) }

    it do
      expect(product).to respond_to :name_en
      expect(product).to respond_to :name_fr
      expect(product).to respond_to :description_en
      expect(product).to respond_to :description_fr
      expect(product).to respond_to :fee_chf
      expect(product).to respond_to :fee_eu
      expect(product).to respond_to :year
    end
  end

  describe "Associations" do
    let(:cup) { create(:cup) }
    let(:product) { build(:product, cup: cup) }

    it do
      expect(product).to have_many(:purchases).dependent(:destroy)
      expect(product).to have_many(:kenshis).through(:purchases)
      expect(product).to belong_to :cup
      expect(product).to belong_to(:event).optional
    end
  end

  describe "Validations" do
    let(:cup) { create(:cup) }
    let(:product) { create(:product, cup: cup) }

    it do
      expect(product).to validate_presence_of(:name_en)
      expect(product).to validate_presence_of(:name_fr)
      expect(product).to validate_presence_of(:fee_chf)
      expect(product).to validate_presence_of(:fee_eu)
      expect(product).to validate_uniqueness_of(:name_en).scoped_to(:cup_id)
      expect(product).to validate_uniqueness_of(:name_fr).scoped_to(:cup_id)
      expect(product).to validate_numericality_of(:fee_chf)
      expect(product).to validate_numericality_of(:fee_eu)
    end
  end

  describe "#remaining_spots, #still_available?" do
    context "when product require_personal_infos" do
      let(:cup) { create(:cup) }
      let!(:product_1) { create(:product, cup: cup, quota: 3, require_personal_infos: true) }
      let!(:product_2) { create(:product, cup: cup, quota: 3, require_personal_infos: true) }
      let!(:product_3) { create(:product, cup: cup, quota: 3, require_personal_infos: false) }
      let!(:kenshi) { create(:kenshi) }

      before do
        ENV["DORMITORY_QUOTA"] = "4"
        create(:purchase, product: product_1, kenshi: kenshi)
        create(:purchase, product: product_1)
      end

      after { ENV["DORMITORY_QUOTA"] = nil }

      context "when product quota is not reached" do
        before { create(:purchase, product: product_2) }

        it do
          expect(product_1.remaining_spots).to eq 1
          expect(product_2.remaining_spots).to eq 1
          expect(product_3.remaining_spots).to eq 3
          expect(product_1).to be_still_available
          expect(product_2).to be_still_available
          expect(product_3).to be_still_available
        end
      end

      context "when product quota is reached" do
        context "when different kenshis bought the products" do
          before { create_list(:purchase, 2, product: product_2) }

          it do
            expect(product_1.remaining_spots).to eq 0
            expect(product_2.remaining_spots).to eq 0
            expect(product_3.remaining_spots).to eq 3
            expect(product_1).not_to be_still_available
            expect(product_2).not_to be_still_available
            expect(product_3).to be_still_available
          end
        end

        context "when same kenshi bought 2 different product" do
          before do
            create(:purchase, product: product_2, kenshi: kenshi)
            create(:purchase, product: product_2)
          end

          it do
            expect(product_1.remaining_spots).to eq 1
            expect(product_2.remaining_spots).to eq 1
            expect(product_3.remaining_spots).to eq 3
            expect(product_1).to be_still_available
            expect(product_2).to be_still_available
            expect(product_3).to be_still_available
          end
        end
      end
    end

    context "when product doesn't require_personal_infos" do
      let(:cup) { create(:cup) }
      let!(:product) { create(:product, cup: cup, quota: quota) }

      before do
        create_list(:purchase, 2, product: product)
      end

      context "without quota" do
        let(:quota) { nil }

        it do
          expect(product.remaining_spots).to be_nil
          expect(product).to be_still_available
        end
      end

      context "with purchases count < quota" do
        let(:quota) { 3 }

        it do
          expect(product.remaining_spots).to eq 1
          expect(product).to be_still_available
        end
      end

      context "with purchases count == quota" do
        let(:quota) { 2 }

        it do
          expect(product.remaining_spots).to eq 0
          expect(product).not_to be_still_available
        end
      end
    end
  end
end
