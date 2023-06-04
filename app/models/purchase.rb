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
    return if product.blank?

    all_dormitory_purchases_for_cup = Purchase
      .joins(:product)
      .where(products: {cup_id: product.cup_id, require_personal_infos: true})
    return if all_dormitory_purchases_for_cup.count < ENV.fetch("DORMITORY_QUOTA", 50).to_i

    errors.add(:product_id, :quota_reached)
  end

  private def basic_quota_validation
    return if product&.quota.nil? || product.purchases.count < product.quota

    errors.add(:product_id, :quota_reached)
  end
end
