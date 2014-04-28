require "acts_as_fighter"
class Kenshi < ActiveRecord::Base

  acts_as_fighter

  GRADES = %w[kyu 1Dan 2Dan 3Dan 4Dan 5Dan 6Dan 7Dan 8Dan]
  FEES = {adult: {chf: 30, eur: 25}, junior: {chf: 16, eur: 14}, dormitory: {chf: 16, eur: 14}, dinner: {chf: 25, eur: 22}}

  belongs_to :cup, inverse_of: :kenshis
  belongs_to :user, inverse_of: :kenshis
  belongs_to :club, inverse_of: :kenshis
  has_many :participations, dependent: :destroy, autosave: true
  has_many :individual_categories, through: :participations
  has_many :teams, through: :participations

  validates_presence_of :cup_id
  validates_presence_of :user_id
  # validates_presence_of :club_id
  validates_presence_of :first_name
  validates_presence_of :last_name
  validates_presence_of :grade
  validates_presence_of :dob
  validates_uniqueness_of :last_name, scope: :first_name
  validates_inclusion_of :grade, in: GRADES

  accepts_nested_attributes_for :participations, allow_destroy: true

  def self.from(user)
    enrollment = self.new(
      first_name: user.first_name,
      last_name: user.last_name,
      female: user.female,
      dob: user.dob,
      email: user.email,
      club: user.club
    )
  end

  def club_name=(club_name)
    self.club = Club.find_or_initialize_by name: club_name
  end


  def takes_part_to?(category)
    self.participations.map(&:category).include? category
  end

  def individual_category_ids=(ids)
    Rails.logger.debug "INDIVIDUAL_CATEGORY_IDS: #{ids}"
    ids.each do |id|
      self.participations.new category: IndividualCategory.find(id)
    end
  end

  def full_name
    "#{first_name} #{last_name}"
  end

  def norm_first_name
    first_name.try :titleize
  end

  def norm_last_name
    last_name.try :titleize
  end

  def norm_club
    club.name.try :titleize
  end
end
