# frozen_string_literal: true

class Participation < ApplicationRecord
  include ActsAsFighter

  attr_writer :category_individual, :category_team
  belongs_to :category, polymorphic: true, autosave: true
  belongs_to :kenshi, inverse_of: :participations
  belongs_to :team, optional: true

  before_validation :assign_category
  after_commit :update_purchase

  validates :pool_position, presence: {if: lambda { |p| p.pool_number.present? }}
  validates :kenshi_id,
    uniqueness: {scope: [:category_type, :category_id], if: ->(p) { p.ronin.blank? }, allow_nil: true}
  validates :pool_number, numericality: {only_integer: true, greater_than: 0, allow_nil: true}

  validates_each :category do |participation, attr, value|
    kenshi = participation.kenshi
    category = participation.category
    next unless kenshi && category

    age = kenshi.age_at_cup
    if category.present?
      if category.min_age && age < category.min_age
        participation.errors.add(attr, :too_young, name: category.name)
      end
      if category.max_age && age > category.max_age
        participation.errors.add(attr, :too_old, name: category.name)
      end
    end
  end

  delegate :product_junior, :product_adult, to: :cup
  delegate :full_name, to: "kenshi", allow_nil: true
  delegate :grade, to: "kenshi", allow_nil: true
  delegate :club, to: "kenshi", allow_nil: true
  delegate :cup, to: "kenshi", allow_nil: true

  def self.no_pool
    where(pool_number: nil)
  end

  def self.to(category)
    where(category: category)
  end

  def self.ronins
    where(ronin: true)
  end

  def product
    kenshi.junior? ? product_junior : product_adult
  end

  def purchase
    kenshi.purchases.find_by(product: product)
  end

  def category_individual
    category.id if category.is_a?(IndividualCategory)
  end

  def category_team
    category.id if category.is_a?(TeamCategory)
  end

  def update_purchase
    if destroyed?
      purchase&.destroy!
    elsif purchase.nil? && product.present?
      kenshi.purchases.create!(product: product)
    end
  end

  def team_name
    return unless category.is_a?(TeamCategory)

    team&.name
  end

  def team_name=(team_name)
    if category.is_a? TeamCategory
      if team_name.blank? && ronin.blank?
        mark_for_destruction
      end
      if team_name.present?
        # self.team_id = nil
        self.ronin = nil
        self.team = Team.find_or_initialize_by team_category: category, name: team_name
      elsif team_name.blank? || ronin.present?
        self.team = nil
      end
    end
  end

  def descriptive_name
    full_name = [category.name]
    full_name << "(#{team.name})" if team
    full_name << "(ronin)" if ronin
    full_name.join(" ")
  end

  protected def assign_category
    if @category_individual.present? && @category_team.present?
      errors.add(:category, "can't have both an individual and a team category")
    end
    if @category_individual.present?
      self.category = IndividualCategory.find(@category_individual)
    end
    if @category_team.present?
      self.category = TeamCategory.find(@category_team)
    end
  end
end
