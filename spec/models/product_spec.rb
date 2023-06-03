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

  describe "#still_available?" do
    let(:cup) { create(:cup) }
    let!(:product) { create(:product, cup: cup, quota: quota) }

    before do
      create_list(:purchase, 2, product: product)
    end

    context "without quota" do
      let(:quota) { nil }

      it { expect(product).to be_still_available }
    end

    context "with purchases count < quota" do
      let(:quota) { 3 }

      it { expect(product).to be_still_available }
    end

    context "with purchases count == quota" do
      let(:quota) { 2 }

      it { expect(product).not_to be_still_available }
    end
  end
end
