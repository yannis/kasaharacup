# frozen_string_literal: true

class Order < ApplicationRecord
  include AASM

  belongs_to :user
  belongs_to :cup
  has_many :purchases
  has_many :products, through: :purchases


  aasm column: :state, no_direct_assignment: true do
    state :pending, initial: true
    state :paid
    state :cancelled

    event :pay do
      transitions from: :pending, to: :paid
    end

    event :cancel do
      transitions from: :pending, to: :cancelled
    end
  end
end
