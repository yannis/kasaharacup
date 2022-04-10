# frozen_string_literal: true

require "rails_helper"
require "cancan/matchers"

RSpec.describe(Ability) do
  let!(:cup) { create(:cup) }
  let!(:ability) { described_class.new(user) }

  context "when user guest" do
    let!(:user) { build(:user) }

    it do
      expect(ability).not_to be_able_to(:register, cup)
    end
  end

  context "when user is logged in" do
    context "when user is admin" do
      let!(:user) { create(:user, :admin) }

      it do
        expect(ability).to be_able_to(:register, cup)
      end
    end

    context "when user is not admin" do
      let!(:user) { create(:user) }

      describe "cup" do
        context "when cup is registerable" do
          it do
            expect(ability).to be_able_to(:register, cup)
          end
        end

        context "when cup is not registerable" do
          before do
            allow(cup).to receive(:registerable?).and_return(false)
          end

          it do
            expect(ability).not_to be_able_to(:register, cup)
          end
        end
      end
    end
  end
end
