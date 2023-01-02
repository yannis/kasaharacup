# frozen_string_literal: true

require "rails_helper"

RSpec.describe Purchase, type: :model do
  describe "Associations" do
    let(:purchase) { build(:purchase) }

    it do
      expect(purchase).to belong_to(:kenshi).inverse_of(:purchases)
      expect(purchase).to belong_to(:order).inverse_of(:purchases).optional
      expect(purchase).to belong_to(:product).inverse_of(:purchases)
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

  describe "Callbacks" do
    describe "before_validation" do
      describe "#set_order" do
        let(:cup) { create(:cup) }
        let(:user) { create(:user) }
        let(:kenshi) { create(:kenshi, user: user, cup: cup) }
        let(:purchase) { build(:purchase, kenshi: kenshi, order: order) }

        context "when order is set" do
          let(:order) { create(:order, user: user, cup: cup) }

          it do
            expect { purchase.valid? }
              .to not_change(Order, :count)
              .and(not_change { purchase.order }.from(order))
          end
        end

        context "when order is not set" do
          let(:order) { nil }

          context "when no order pre-exists" do
            it do
              expect { purchase.valid? }
                .to change(Order, :count).by(1)
                .and(change { purchase.order }.from(nil))
            end
          end

          context "when an order pre-exists" do
            context "when order is pending" do
              let!(:previous_order) { create(:order, user: user, cup: cup) }

              it do
                expect { purchase.valid? }
                  .to not_change(Order, :count)
                  .and(change { purchase.order }.from(nil).to(previous_order))
              end
            end

            context "when order is paid" do
              before do
                create(:order, user: user, cup: cup).pay!
              end

              it do
                expect { purchase.valid? }
                  .to change(Order, :count)
                  .and(change { purchase.order }.from(nil).to(Order.last))
              end
            end
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
