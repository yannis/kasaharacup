# frozen_string_literal: true

require "rails_helper"

describe(Order) do
  describe("Associations") do
    let(:order) { build(:order) }

    it do
      expect(order).to(belong_to(:user))
      expect(order).to(belong_to(:cup))
      expect(order).to(have_many(:purchases))
      expect(order).to(have_many(:products).through(:purchases))
    end
  end

  describe ("State machine") do
    let(:order) { build(:order) }

    it do
      expect(order).to(have_state(:pending))
    end

    it do
      expect(order).to(transition_from(:pending).to(:paid).on_event(:pay))
      expect(order).to(transition_from(:pending).to(:cancelled).on_event(:cancel))
    end
  end
end
