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

  describe("States") do
    let(:order) { build(:order) }

    it { expect(order).to be_pending }
  end
end
