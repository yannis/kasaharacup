# frozen_string_literal: true

class Participation < ApplicationRecord
  include ActsAsFighter

  attr_writer :category_individual, :category_team
  belongs_to :category, polymorphic: true, autosave: true
  belongs_to :kenshi, inverse_of: :participations, touch: true
  belongs_to :team, optional: true

  validates :pool_position, presence: {if: lambda { |p| p.pool_number.present? }}
  validates :kenshi_id,
    uniqueness: {scope: [:category_type, :category_id], if: ->(p) { p.ronin.blank? }, allow_nil: true}
  validates :pool_number, numericality: {only_integer: true, greater_than: 0, allow_nil: true}
  validate :individual_or_team_category
  validate :category_age
  validate :category_gender

  before_validation :assign_category
  before_validation :reset_pool_position_on_pool_change
  before_validation :auto_assign_pool_position

  delegate :full_name, to: "kenshi", allow_nil: true
  delegate :grade, to: "kenshi", allow_nil: true
  delegate :club, to: "kenshi", allow_nil: true
  delegate :cup, to: "kenshi", allow_nil: true
  delegate :product_individual_junior, :product_individual_adult, to: :cup

  def self.no_pool
    where(pool_number: nil)
  end

  def self.to(category)
    where(category: category)
  end

  def self.ronins
    where(ronin: true)
  end

  def category_individual
    category.id if category.is_a?(IndividualCategory)
  end

  def category_team
    category.id if category.is_a?(TeamCategory)
  end

  def product
    kenshi.junior? ? product_individual_junior : product_individual_adult
  end

  def purchase
    kenshi.purchases.find_by(product: product)
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

  def pool_label
    return if pool_number.blank? || pool_position.blank?

    "#{pool_number}.#{pool_position}"
  end

  def descriptive_name
    full_name = [category.name]
    full_name << "(#{team.name})" if team
    full_name << "(ronin)" if ronin
    full_name.join(" ")
  end

  private def assign_category
    return unless @category_individual.present? || @category_team.present?

    self.category = if @category_individual.is_a?(IndividualCategory)
      @category_individual
    elsif @category_team.is_a?(TeamCategory)
      @category_team
    elsif @category_individual.present?
      IndividualCategory.find(@category_individual)
    elsif @category_team.present?
      TeamCategory.find(@category_team)
    end
  end

  private def individual_or_team_category
    return unless @category_individual.present? && @category_team.present?

    errors.add(:category, "can't have both an individual and a team category")
  end

  private def category_age
    return unless kenshi && category

    age = kenshi.age_at_cup
    if category.present?
      if category.min_age && age < category.min_age
        errors.add(:category, :too_young, name: category.name)
      end
      if category.max_age && age > category.max_age
        errors.add(:category, :too_old, name: category.name)
      end
    end
  end

  private def category_gender
    return unless kenshi && category&.gender_restriction

    expected_female = category.gender_restriction == "female"
    if kenshi.female != expected_female
      errors.add(:category, :wrong_gender, name: category.name)
    end
  end

  private def reset_pool_position_on_pool_change
    return unless persisted?
    return unless pool_number_changed?
    return if pool_position_changed?

    self.pool_position = nil
  end

  private def auto_assign_pool_position
    return if pool_number.blank?
    return if pool_position.present?

    scope = self.class.where(category_type: category_type, category_id: category_id,
      pool_number: pool_number)
    scope = scope.where.not(id: id) if persisted?
    self.pool_position = (scope.maximum(:pool_position) || 0) + 1
  end
end
