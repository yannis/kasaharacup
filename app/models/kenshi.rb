# frozen_string_literal: true

class Kenshi < ApplicationRecord
  include ActsAsFighter
  GRADES = %w[kyu 1Dan 2Dan 3Dan 4Dan 5Dan 6Dan 7Dan 8Dan]

  belongs_to :cup, inverse_of: :kenshis
  belongs_to :user, inverse_of: :kenshis
  belongs_to :club, inverse_of: :kenshis
  has_one :personal_info, dependent: :destroy, inverse_of: :kenshi
  has_many :participations, inverse_of: :kenshi, dependent: :destroy, autosave: true
  has_many :individual_categories, through: :participations, source: :category,
    source_type: "IndividualCategory"
  has_many :team_categories, through: :participations, source: :category, source_type: "TeamCategory"
  has_many :teams, through: :participations
  has_many :purchases, dependent: :destroy
  has_many :products, through: :purchases

  validates :first_name, presence: true
  validates :last_name, presence: true
  validates :grade, presence: true
  validates :dob, presence: true
  validates :last_name, uniqueness: {scope: [:cup_id, :first_name], case_sensitive: true}
  validates :grade, inclusion: {in: GRADES}
  validates :female, inclusion: {in: [true, false]}

  accepts_nested_attributes_for :participations, allow_destroy: true
  accepts_nested_attributes_for :purchases, allow_destroy: true
  accepts_nested_attributes_for :personal_info, allow_destroy: true

  before_validation :format
  after_validation :logs
  after_create_commit :notify_slack
  after_commit :update_purchase

  def self.from(user)
    new(
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
    self.club = if club_name.blank?
      nil
    else
      Club.find_or_initialize_by name: club_name
    end
  end

  def club_name
    club.try(:name)
  end

  # here we take into account only the year of birth
  # example: in 2022, someone bor on 31.12.2005 has
  # `#age_at_cup == 17` when in fact they will be 16
  def age_at_cup
    return 0 if dob.blank? || cup.year.blank?

    (cup.start_on.to_date - dob).to_i.days.in_years.to_i
  end

  def junior?
    age_at_cup < 18
  end

  def adult?
    !junior?
  end

  def takes_part_to?(category)
    participations.map(&:category).include? category
  end

  def consume?(product)
    purchases.map(&:product).include? product
  end

  def individual_category_ids=(ids)
    ids.each do |id|
      participations.new category: IndividualCategory.find(id)
    end
  end

  def full_name
    "#{norm_first_name} #{norm_last_name}"
  end

  def norm_first_name
    # first_name.try :titleize
    first_name&.mb_chars&.gsub(/[[:alpha:]]+/) { |w| w.capitalize }
  end

  def norm_last_name
    # last_name.try :titleize
    last_name&.gsub(/[[:alpha:]]+/) { |w| w.capitalize }
  end

  def norm_club
    # club.name.try :titleize
    club.name.gsub(/[[:alpha:]]+/) { |w| w.capitalize } if club.try(:name)
  end

  def purchased?(product)
    products.include? product
  end

  def fees(currency = :chf)
    products.sum { |product| (currency.to_sym == :chf) ? product.fee_chf : product.fee_eu }
  end

  def poster_name(category: nil)
    poster_name = [last_name]

    if Kenshi.includes(:cup).where(last_name: last_name, cup: category&.cup.presence || Cup.last).size > 1
      poster_name << first_name.split(/[\s|-]/).map { |s|
        s.first + "."
      }.join
    end
    poster_name.join(" ").mb_chars.unicode_normalize(:nfkd).gsub(/[^\x00-\x7F]/n, "").upcase.to_s
  end

  def logs
    Rails.logger.debug { "errors: #{errors.inspect}" }
  end

  def fitness
    (grade.to_f / age_at_cup.to_f).round(4)
  end

  private def format
    # use POSIX bracket expression here
    self.last_name = last_name.gsub(/[[:alpha:]]+/) { |w| w.capitalize } if last_name
    self.first_name = first_name.mb_chars.gsub(/[[:alpha:]]+/) { |w| w.capitalize } if first_name
    self.email = email.downcase if email
  end

  private def notify_slack
    notification = Slack::Notifications::Registration.new(self)
    Slack::NotificationService.new.call(notification: notification)
  end

  private def update_purchase
    Kenshis::CalculatePurchasesService.new(kenshi: self).call
  end
end
