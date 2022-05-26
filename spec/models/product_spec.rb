# frozen_string_literal: true

require "rails_helper"

RSpec.describe Product, type: :model do
  let(:product) { build(:product) }

  it { expect(product).to have_many(:purchases).dependent(:destroy) }
  it { expect(product).to have_many(:kenshis).through(:purchases) }

  it { expect(product).to belong_to :cup }
  it { expect(product).to belong_to(:event).optional }

  it { expect(product).to respond_to :name_en }
  it { expect(product).to respond_to :name_fr }
  it { expect(product).to respond_to :description_en }
  it { expect(product).to respond_to :description_fr }
  it { expect(product).to respond_to :fee_chf }
  it { expect(product).to respond_to :fee_eu }
  it { expect(product).to respond_to :year }

  it { expect(product).to validate_presence_of :name_en }
  it { expect(product).to validate_presence_of :name_fr }
  it { expect(product).to validate_presence_of :fee_chf }
  it { expect(product).to validate_presence_of :fee_eu }

  it { expect(product).to validate_uniqueness_of(:name_en).scoped_to(:cup_id) }
  it { expect(product).to validate_uniqueness_of(:name_fr).scoped_to(:cup_id) }

  it { expect(product).to validate_numericality_of(:fee_chf) }
  it { expect(product).to validate_numericality_of(:fee_eu) }

  describe "#still_available?" do
    let(:product) { create(:product, quota: quota, purchases: build_list(:purchase, 2)) }

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
