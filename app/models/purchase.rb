# frozen_string_literal: true

class Purchase < ApplicationRecord
  belongs_to :kenshi, inverse_of: :purchases
  belongs_to :product, inverse_of: :purchases

  validate :in_quota

  def descriptive_name
    "#{product.name} (#{product.fee_chf} CHF / #{product.fee_eu} €)"
  end

  private def in_quota
    if product&.require_personal_infos
      dormitory_quota_validation
    else
      basic_quota_validation
    end
  end

  private def dormitory_quota_validation
    # We need this validation as in our dormitory, a kenshi cannot reuse the bed
    # of another kenshi another night.
    kenshis_in_dormitory_for_cup = Kenshi
      .joins(purchases: :product)
      .merge(Product.where(cup_id: product.cup_id, require_personal_infos: true))
      .distinct
    return if kenshis_in_dormitory_for_cup.count < ENV.fetch("DORMITORY_QUOTA", 50).to_i

    errors.add(:product_id, :quota_reached)
  end

  private def basic_quota_validation
    return if product&.quota.nil? || product.purchases.count < product.quota

    errors.add(:product_id, :quota_reached)
  end
end
