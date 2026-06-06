# frozen_string_literal: true

class IndividualCategory < ApplicationRecord
  include ActsAsCategory

  belongs_to :cup, inverse_of: :individual_categories
  has_many :participations, as: :category, dependent: :destroy # inverse_of not working with polymorphic associations
  has_many :kenshis, through: :participations
  has_many :documents, as: :category, dependent: :destroy
  has_many :videos, as: :category, dependent: :destroy
  has_many :bracket_fights, -> { where(pool_number: nil) }, class_name: "Fight", inverse_of: :individual_category
  has_many :pool_fights, -> { where.not(pool_number: nil) }, class_name: "Fight", inverse_of: :individual_category

  delegate :year, to: :cup

  def full_name
    "#{name} (#{cup.year})"
  end

  # All pool fights for the category, loaded once with their fighters/points and
  # grouped by pool number. PoolComponent reads its slice from here so rendering
  # every pool costs a single fights query instead of one per pool.
  def pool_fights_by_number
    @pool_fights_by_number ||= pool_fights
      .includes(:fighter_1, :fighter_2, :winner, :fight_points)
      .group_by(&:pool_number)
  end

  # Category-scoped poster names for every kenshi shown in the pools, batched
  # into one query instead of an exists? check per fighter (Kenshi#poster_name).
  def pool_poster_names
    @pool_poster_names ||= Kenshi.poster_names_for(pool_kenshis, category: self)
  end

  private def pool_kenshis
    from_pools = pools.flat_map(&:participations).filter_map(&:kenshi)
    from_fights = pool_fights_by_number.values.flatten.flat_map { |fight| [fight.fighter_1, fight.fighter_2] }
    (from_pools + from_fights).compact.uniq(&:id)
  end
end
