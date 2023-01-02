# frozen_string_literal: true

class Purchase < ApplicationRecord
  belongs_to :kenshi, inverse_of: :purchases
  belongs_to :order, inverse_of: :purchases, optional: true
  belongs_to :product, inverse_of: :purchases

  validates :order, presence: {if: ->(p) { p.kenshi&.cup.present? && p.kenshi.cup.start_on >= Date.parse("2023-01-01") }}
  validate :in_quota

  before_validation :set_order

  delegate :cup, :user, to: :kenshi, allow_nil: true

  def descriptive_name
    "#{product.name} (#{product.fee_chf} CHF / #{product.fee_eu} €)"
  end

  private def in_quota
    return if product&.quota.nil? || product.purchases.count < product.quota

    errors.add(:product_id, :quota_reached)
  end

  private def set_order
    return if order.present? || [user, cup].any?(&:blank?)

    self.order = Order.find_or_create_by!(user: user, cup: cup, state: :pending)
  end
end
