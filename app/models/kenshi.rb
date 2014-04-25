require "acts_as_fighter"
class Kenshi < ActiveRecord::Base

  acts_as_fighter

  GRADES = %w[kyu 1Dan 2Dan 3Dan 4Dan 5Dan 6Dan 7Dan 8Dan]
  FEES = {adult: {chf: 30, eur: 25}, junior: {chf: 16, eur: 14}, dormitory: {chf: 16, eur: 14}, dinner: {chf: 25, eur: 22}}

  belongs_to :cup, inverse_of: :kenshis
  belongs_to :user, inverse_of: :kenshis
  belongs_to :club, inverse_of: :kenshis
  has_many :participations, inverse_of: :kenshi, dependent: :destroy
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
  # accepts_nested_attributes_for :club, allow_destroy: true

  def club_name=(club_name)
    self.club = Club.find_or_initialize_by name: club_name
  end

  def participation_attributes=(participation_attributes)
    participation_attributes.each do |k,a|


      category_type = a.fetch :category_type, nil
      category_id = a.fetch :category_id, nil
      participation_id = a.fetch :id, nil
      team_name = a.fetch :team_name, nil
      ronin = a.fetch :ronin, nil
      # participate a.fetch :participate, nil

      participation = self.participations.find(participation_id) if participation_id
      Rails.logger.debug "PARTICIPATION: #{participation.inspect}"

      if category_type == "TeamCategory"
        category = TeamCategory.find category_id
        params = {team_name: team_name, ronin: ronin}
        if participation.present?
          participation.update_attributes params
        else
          self.participations.new params.merge! category: category
        end
      elsif category_type == "IndividualCategory"
        category = IndividualCategory.find category_id
        if participation
          participation.destroy unless participate
        else
          self.participations.new category: category
        end
      end
    end
  end


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
