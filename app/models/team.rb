# frozen_string_literal: true

class Team < ApplicationRecord
  include ActsAsFighter

  belongs_to :team_category, inverse_of: :teams
  has_many :participations, dependent: :destroy
  has_many :kenshis, through: :participations

  validates :name, presence: true
  validates :name, uniqueness: {scope: :team_category_id}
  validate :number_of_participations

  delegate :cup, to: :team_category

  def self.empty
    includes(:participations)
      .where(participations: {team_id: nil})
  end

  def self.incomplete
    joins(:participations)
      .group("teams.id")
      .having("COUNT(participations.id) < 5")
  end

  def self.complete
    joins(:participations)
      .group("teams.id")
      .having("COUNT(participations.id) >= 5")
  end

  def self.valid
    joins(:participations)
      .group("teams.id")
      .having("COUNT(participations.id) >= 3")
  end

  def self.invalid
    joins(:participations)
      .group("teams.id")
      .having("COUNT(participations.id) < 3")
  end

  def self.tree
    Tree.new(self)
  end

  def to_s
    name
  end

  def complete?
    participations.size >= 5
  end

  def incomplete?
    !complete?
  end

  def isvalid?
    participations.size > 2
  end

  def name_and_status
    name_and_status = [name]
    name_and_status << "(complete)" if complete?
    name_and_status.join(" ")
  end

  def name_and_category
    "#{name} (#{team_category.name})"
  end

  def category_and_name
    "#{team_category.name} (#{name})"
  end

  def poster_name
    name.mb_chars.unicode_normalize(:nfkd).gsub(/[^\x00-\x7F]/n, "").upcase.to_s
  end

  def fitness
    kenshis.inject(0) { |sum, k| sum + k.fitness }
  end

  protected def number_of_participations
    if participations.count > 6
      errors.add(:participations,
        I18n.t("activerecord.errors.models.team.participations"))
    end
  end
end
