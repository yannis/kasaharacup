# frozen_string_literal: true

class Purchase < ApplicationRecord
  belongs_to :kenshi, inverse_of: :purchases
  belongs_to :product, inverse_of: :purchases
end
