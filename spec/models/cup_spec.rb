# frozen_string_literal: true

require "rails_helper"

RSpec.describe Cup do
  describe "Associations" do
    let(:cup) { build(:cup) }

    it do
      expect(cup).to belong_to(:product_individual_junior).class_name("Product").optional
      expect(cup).to belong_to(:product_individual_adult).class_name("Product").optional
      expect(cup).to belong_to(:product_team).class_name("Product").optional
      expect(cup).to belong_to(:product_full_junior).class_name("Product").optional
      expect(cup).to belong_to(:product_full_adult).class_name("Product").optional
      expect(cup).to have_many(:individual_categories).dependent(:destroy)
      expect(cup).to have_many(:team_categories).dependent(:destroy)
      expect(cup).to have_many(:events).dependent :destroy
      expect(cup).to have_many(:headlines).dependent :destroy
      expect(cup).to have_many(:kenshis).dependent :destroy
      expect(cup).to have_many(:products).dependent :destroy
      expect(cup).to have_one_attached(:header_image)
    end
  end

  describe "Translations" do
    let(:cup) { build(:cup) }

    it { expect(cup).to translate(:description) }
  end

  describe "Validations" do
    let(:cup) { create(:cup) }

    it do
      expect(cup).to validate_presence_of(:start_on)
      expect(cup).to validate_uniqueness_of(:start_on)
      expect(cup).to validate_presence_of(:deadline)
      expect(cup).to validate_presence_of(:year)
      expect(cup).to validate_uniqueness_of(:year).allow_blank
    end

    describe "#header_image_is_image" do
      let(:cup) { create(:cup) }

      context "with a valid file type" do
        before do
          cup.header_image.attach(
            io: Rails.root.join("spec/fixtures/images/kasa.jpg").open,
            filename: "burger.jpg",
            content_type: "image/jpeg"
          )
        end

        it do
          expect(cup).to be_valid
          expect(cup.header_image).to be_attached
        end
      end

      context "with an invalid file type" do
        let!(:cup) { build(:cup, header_image: nil) }

        it do
          cup.header_image.attach(
            io: Rails.root.join("spec/fixtures/test.pdf").open,
            filename: "a_csv.csv",
            content_type: "application/csv"
          )
          expect(cup).not_to be_valid
          expect(cup.header_image).not_to be_attached
          expect(cup.errors[:header_image]).to contain_exactly("must be an image")
        end
      end
    end
  end

  describe "A cup without deadline" do
    let(:cup) { create(:cup) }

    it { expect(cup.deadline).not_to be_nil }
  end

  describe "4 cups, 2 pasts, 2 futures" do
    before { described_class.destroy_all }

    let!(:cup1) { create(:cup, start_on: Date.current - 2.years) }
    let!(:cup2) { create(:cup, start_on: Date.current - 1.year) }
    let!(:cup3) { create(:cup, start_on: Date.current + 1.year) }
    let!(:cup4) { create(:cup, start_on: Date.current + 2.years) }

    it { expect(cup1).to be_past }
    it { expect(described_class.count).to be 4 }
    it { expect(cup4).not_to be_past }
    it { expect(described_class.all).to contain_exactly(cup1, cup2, cup3, cup4) }
    it { expect(described_class.past).to contain_exactly(cup1, cup2) }
    it { expect(described_class.future).to contain_exactly(cup3, cup4) }
  end

  describe "#canceled?" do
    let(:cup) { build(:cup) }

    it { expect(cup).not_to be_canceled }

    context "when canceled_at is set" do
      before { cup.canceled_at = Time.current }

      it { expect(cup).to be_canceled }
    end
  end

  describe "#registerable?" do
    let(:cup) { build(:cup) }

    it { expect(cup).to be_registerable }

    context "when canceled" do
      let(:cup) { build(:cup, canceled_at: 1.minute.ago) }

      it { expect(cup).not_to be_registerable }
    end

    context "when deadline has past" do
      let(:cup) { build(:cup, deadline: 1.minute.ago) }

      it { expect(cup).not_to be_registerable }
    end

    context "when registerable_at is in the past" do
      let(:cup) { build(:cup, registerable_at: 1.minute.ago) }

      it { expect(cup).to be_registerable }
    end

    context "when registerable_at is in the future" do
      let(:cup) { build(:cup, registerable_at: 1.minute.from_now) }

      it { expect(cup).not_to be_registerable }
    end
  end

  describe "#not_yet_registerable?" do
    let(:cup) { build(:cup) }

    it { expect(cup).not_to be_not_yet_registerable }

    context "when canceled" do
      let(:cup) { build(:cup, canceled_at: 1.minute.ago) }

      it { expect(cup).not_to be_not_yet_registerable }
    end

    context "when deadline has past" do
      let(:cup) { build(:cup, deadline: 1.minute.ago) }

      it { expect(cup).not_to be_not_yet_registerable }
    end

    context "when registerable_at is in the past" do
      let(:cup) { build(:cup, registerable_at: 1.minute.ago) }

      it { expect(cup).not_to be_not_yet_registerable }
    end

    context "when registerable_at is in the future" do
      let(:cup) { build(:cup, registerable_at: 1.minute.from_now) }

      it { expect(cup).to be_not_yet_registerable }
    end
  end
end
