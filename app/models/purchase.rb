# frozen_string_literal: true

class Purchase < ApplicationRecord
  belongs_to :kenshi, inverse_of: :purchases
  belongs_to :product, inverse_of: :purchases

  validate :in_quota

  def descriptive_name
    "#{product.name} (#{product.fee_chf} CHF / #{product.fee_eu} €)"
  end

  private def in_quota
    return if product.nil? || product.still_available?

    errors.add(:product_id, :quota_reached)
  end
end
