# require 'to_csv'
require 'acts_as_fighter'
class Team < ActiveRecord::Base
  # csvable
  # attr_accessible :name
  acts_as_fighter
  belongs_to :team_category, inverse_of: :teams
  has_many :participations, dependent: :destroy
  has_many :kenshis, through: :participations

  validates_presence_of :name
  validates_uniqueness_of :name, scope: :team_category_id
  validate :number_of_participations

  def self.empty
    includes(:participations).
    where(participations: {team_id: nil} )
  end

  def self.incomplete
    joins(:participations).
    group('teams.id').
    having('COUNT(participations.id) < 5')
  end

  def self.complete
    joins(:participations).
    group('teams.id').
    having('COUNT(participations.id) >= 5')
  end

  def self.valid
    joins(:participations).
    group('teams.id').
    having('COUNT(participations.id) >= 3')
  end

  def self.invalid
    joins(:participations).
    group('teams.id').
    having('COUNT(participations.id) < 3')
  end


  def self.tree
    Tree.new(self)
  end

  def to_s
    name
  end

  def complete?
    participations.count >= 5
  end

  def incomplete?
    !complete?
  end

  def isvalid?
    participations.count > 2
  end

  def name_and_status
    name_and_status = [name]
    name_and_status << "(complete)" if complete?
    return name_and_status.join(' ')
  end

  def name_and_category
    "#{name} (#{team_category.name})"
  end

  def category_and_name
    "#{team_category.name} (#{name})"
  end

  def poster_name
    name.mb_chars.normalize(:kd).gsub(/[^\x00-\x7F]/n,'').upcase.to_s
  end

  protected

  def number_of_participations
    errors.add(:participations, I18n.t('activerecord.errors.models.team.participations')) if self.participations.count > 6
  end
end
