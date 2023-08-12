# frozen_string_literal: true

require "translate"
class Product < ApplicationRecord
  belongs_to :cup
  belongs_to :event, optional: true
  has_many :purchases, dependent: :destroy, autosave: true
  has_many :kenshis, through: :purchases

  validates :name_en, presence: true, uniqueness: {scope: :cup_id}
  validates :name_fr, presence: true, uniqueness: {scope: :cup_id}
  validates :fee_chf, presence: true, numericality: {allow_nil: true}
  validates :fee_eu, presence: true, numericality: {allow_nil: true}
  validates :quota, numericality: {allow_nil: true, only_integer: true, greater_than: 0}

  translate :name, :description

  delegate :year, to: :cup

  def still_available?
    if require_personal_infos
      dormitory_still_available
    else
      quota.nil? || purchases.count < quota
    end
  end

  def dormitory_still_available
    # We need this validation as in our dormitory, a kenshi cannot reuse the bed
    # of another kenshi another night.
    kenshis_in_dormitory_for_cup = Kenshi
      .joins(purchases: :product)
      .merge(Product.where(cup_id: cup_id, require_personal_infos: true))
      .distinct
    kenshis_in_dormitory_for_cup.count < ENV.fetch("DORMITORY_QUOTA", 50).to_i
  end
end
