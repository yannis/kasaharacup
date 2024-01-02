# frozen_string_literal: true

require "rails_helper"

RSpec.describe Participation do
  describe "Attributes" do
    let(:participation) { build(:participation) }

    it do
      expect(participation).to respond_to :pool_number
      expect(participation).to respond_to :pool_position
      expect(participation).to respond_to :ronin
      expect(participation).to respond_to :fighting_spirit
    end
  end

  describe "Associations" do
    let(:participation) { build(:participation) }

    it { expect(participation).to belong_to :category }
    it { expect(participation).to belong_to :kenshi }
    it { expect(participation).to belong_to(:team).optional }
  end

  describe "Delegations" do
    let(:participation) { build(:participation) }

    it do
      expect(participation).to delegate_method(:product_individual_junior).to(:cup)
      expect(participation).to delegate_method(:product_individual_adult).to(:cup)
      expect(participation).to delegate_method(:full_name).to(:kenshi).allow_nil
      expect(participation).to delegate_method(:grade).to(:kenshi).allow_nil
      expect(participation).to delegate_method(:club).to(:kenshi).allow_nil
    end
  end

  describe "Callbacks" do
    describe "before_validation" do
      describe "#assign_category" do
        let!(:cup) { create(:cup) }
        let!(:team_category) { create(:team_category, cup: cup) }
        let!(:individual_category) { create(:individual_category, cup: cup) }
        let!(:kenshi) { create(:kenshi, cup: cup) }
        let!(:participation) { build(:participation, kenshi: kenshi, category: nil) }

        context "when both ronin and team_category_id are set" do
          before do
            participation.update(ronin: true, category: team_category)
          end

          it { expect(participation).to be_valid_verbose }
          it { expect(described_class.ronins.to_a).to eql [participation] }
          it { expect(participation.cup).to eql cup }
        end

        context "when individual_category is set" do
          before do
            participation.category_individual = individual_category
          end

          it do
            expect(participation).to be_valid
            expect(participation.category).to eq(individual_category)
          end
        end

        context "when team_category is set" do
          before do
            participation.category_team = team_category
          end

          it do
            expect(participation).to be_valid
            expect(participation.category).to eq(team_category)
          end
        end
      end
    end

    describe "after_commit" do
      describe "#update_purchase" do
        let!(:cup) {
          create(:cup, product_individual_junior: create(:product), product_individual_adult: create(:product))
        }
        let!(:team_category) { build(:team_category, cup: cup) }
        let!(:individual_category) { create(:individual_category, cup: cup) }
        let!(:kenshi) { create(:kenshi, cup: cup) }

        context "when participation is destroyed" do
          let!(:participation) { create(:participation, kenshi: kenshi, category: team_category) }

          it do
            expect { participation.destroy }
              .to change { kenshi.purchases.count }.by(-1)
          end
        end

        context "when participation is created" do
          it do
            expect { create(:participation, kenshi: kenshi, category: team_category) }
              .to change { kenshi.purchases.count }.by(1)
          end
        end
      end
    end
  end

  describe "Validations" do
    describe "#individual_or_team_category" do
      let!(:cup) { create(:cup) }
      let!(:team_category) { create(:team_category, cup: cup) }
      let!(:individual_category) { create(:individual_category, cup: cup) }
      let!(:kenshi) { create(:kenshi, cup: cup) }
      let!(:participation) { build(:participation, kenshi: kenshi, category: nil) }

      before do
        participation.category_team = team_category
        participation.category_individual = individual_category
      end

      it do
        expect(participation).not_to be_valid
        expect(participation.errors[:category])
          .to contain_exactly("can't have both an individual and a team category")
      end
    end

    describe "#category_age" do
      let(:cup) { create(:cup, start_on: 2.months.from_now) }
      let(:individual_category) { create(:individual_category, min_age: 8, max_age: 10, cup: cup) }

      context "when kenshi is too young for the category" do
        let(:kenshi) { create(:kenshi, dob: 6.years.ago.to_date, cup: cup) }
        let(:participation) { build(:participation, kenshi: kenshi, category: individual_category) }

        it {
          participation.valid?
          expect(participation.errors[:category]).to contain_exactly("Désolé, mais vous êtes trop jeune pour
            participer à la catégorie #{individual_category.name}!".squish)
        }
      end

      context "when kenshi is too old for the category" do
        let(:kenshi) { create(:kenshi, dob: 14.years.ago.to_date, cup: cup) }
        let(:participation) { build(:participation, kenshi: kenshi, category: individual_category) }

        it {
          participation.valid?
          expect(participation.errors[:category])
            .to contain_exactly("Désolé, mais vous êtes trop vieux pour participer à la
              catégorie #{individual_category.name}!".squish)
        }
      end
    end
  end

  describe "#product" do
    let!(:product_individual_junior) { build(:product) }
    let!(:product_individual_adult) { build(:product) }
    let!(:cup) {
      create(:cup, product_individual_junior: product_individual_junior,
        product_individual_adult: product_individual_adult)
    }
    let!(:kenshi) { create(:kenshi, cup: cup) }
    let!(:participation) { create(:participation, kenshi: kenshi) }

    context "when kenshi is junior" do
      before { allow(kenshi).to receive(:junior?).and_return(true) }

      it { expect(participation.product).to eq(product_individual_junior) }
    end

    context "when kenshi is adult" do
      before { allow(kenshi).to receive(:junior?).and_return(false) }

      it { expect(participation.product).to eq(product_individual_adult) }
    end
  end

  describe "#purchase" do
    let(:product_individual_adult) { create(:product) }
    let(:cup) { create(:cup, product_individual_adult: product_individual_adult) }
    let(:kenshi) { create(:kenshi, cup: cup) }
    let(:participation) { create(:participation, kenshi: kenshi) }

    it do
      expect(participation.purchase).to be_a(Purchase)
      expect(participation.purchase.product).to eq(product_individual_adult)
    end
  end
end
