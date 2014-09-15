require "acts_as_fighter"
class Kenshi < ActiveRecord::Base

  acts_as_fighter

  GRADES = %w[kyu 1Dan 2Dan 3Dan 4Dan 5Dan 6Dan 7Dan 8Dan]

  belongs_to :cup, inverse_of: :kenshis
  belongs_to :user, inverse_of: :kenshis
  belongs_to :club, inverse_of: :kenshis
  has_many :participations, inverse_of: :kenshi, dependent: :destroy, autosave: true
  # has_many :categories, through: :participations, source: :category

  has_many :individual_categories, through: :participations, source: :category, source_type: "IndividualCategory"
  has_many :team_categories, through: :participations, source: :category, source_type: "TeamCategory"
  has_many :teams, through: :participations
  has_many :purchases, dependent: :destroy, autosave: true
  has_many :products, through: :purchases

  validates_associated :participations

  validates_presence_of :cup_id
  validates_presence_of :user_id
  # validates_presence_of :club_id
  validates_presence_of :first_name
  validates_presence_of :last_name
  validates_presence_of :grade
  validates_presence_of :dob
  validates_uniqueness_of :last_name, scope: :first_name
  validates_inclusion_of :grade, in: GRADES
  validates_inclusion_of :female, in: [true, false]

  accepts_nested_attributes_for :participations, allow_destroy: true
  accepts_nested_attributes_for :purchases, allow_destroy: true

  after_validation :logs

  def self.from(user)
    self.new(
      first_name: user.first_name,
      last_name: user.last_name,
      female: user.female,
      dob: user.dob,
      email: user.email,
      club: user.club
    )
  end

  def self.for_cup(cup)
    where cup: cup
  end

  def club_name=(club_name)
    self.club = Club.find_or_initialize_by name: club_name
  end

  def age_at_cup
    return 0 if dob.blank?
    cup_start = cup.start_on
    cup_start.year - dob.year - ((cup_start.month > dob.month || (cup_start.month == dob.month && cup_start.day >= dob.day)) ? 0 : 1)
  end

  def junior?
    age_at_cup <= 16
  end

  def adult?
    !junior?
  end

  def club_name
    club.try(:name)
  end

  def takes_part_to?(category)
    self.participations.map(&:category).include? category
  end

  def individual_category_ids=(ids)
    ids.each do |id|
      self.participations.new category: IndividualCategory.find(id)
    end
  end

  def full_name
    "#{norm_first_name} #{norm_last_name}"
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

  def purchased?(product)
    self.products.include? product
  end

  def competition_fee(currency)
    if participations.present?
      junior? ? self.cup.junior_fees(currency) : self.cup.adult_fees(currency)
    else
      0
    end
  end

  def products_fee(currency)
    products_fee = 0
    products.each do |product|
      products_fee += (currency.to_sym == :chf ? product.fee_chf : product.fee_eu)
    end
    products_fee
  end

  def fees(currency)
    currency = currency.to_sym
    self.competition_fee(currency)+self.products_fee(currency)
  end


  def poster_name
    poster_name = [last_name]
    poster_name << first_name.split(/[\s|-]/).map{|s| s.first+'.'}.join if Kenshi.where(last_name: last_name).count > 1
    poster_name.join(' ').mb_chars.normalize(:kd).gsub(/[^\x00-\x7F]/n,'').upcase.to_s
  end

  def logs
    Rails.logger.debug "errors: #{self.errors.inspect}"
  end
end
