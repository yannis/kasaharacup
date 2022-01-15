# frozen_string_literal: true

class Purchase < ApplicationRecord
  belongs_to :kenshi, inverse_of: :purchases
  belongs_to :product, inverse_of: :purchases

  def descriptive_name
    descriptive_name = [product.name]
    descriptive_name << "(#{product.fee_chf} CHF / #{product.fee_eu} €)"
    descriptive_name.join(" ")
  end
end
