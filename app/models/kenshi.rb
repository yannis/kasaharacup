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

  scope :shinpans, -> {
    where(shinpan: true).where.missing(:participations)
  }

  scope :not_shinpans, -> {
    where.not(id: shinpans)
  }

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
    first_name&.gsub(/[[:alpha:]]+/) { |w| w.capitalize }
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

    same_name_kenshis = Kenshi.where(last_name: last_name).where.not(id: id)
    same_name_kenshis = if category
      same_name_kenshis.includes(:participations).where(participations: {category:})
    else
      same_name_kenshis.where(cup: cup)
    end
    if same_name_kenshis.exists?
      poster_name << first_name_initials(category:)
    end
    Kenshi.send(:normalize_poster_name, poster_name.join(" "))
  end

  # Batch-computes poster_name for a collection of kenshis with a single DB
  # query, avoiding the N+1 that calling #poster_name in a loop produces.
  # Returns a hash {kenshi.id => poster_name}. Namesake disambiguation is
  # cup-scoped by default, matching #poster_name; pass a category to scope it to
  # that category's participants, matching #poster_name(category:).
  def self.poster_names_for(kenshis, category: nil)
    return {} if kenshis.empty?

    same_name_groups = category ? category_name_groups(kenshis, category) : cup_name_groups(kenshis)
    group_key = category ? ->(kenshi) { kenshi.last_name } : ->(kenshi) { [kenshi.cup_id, kenshi.last_name] }

    kenshis.each_with_object({}) do |kenshi, hash|
      group = same_name_groups.fetch(group_key.call(kenshi), [])
      hash[kenshi.id] = (group.size > 1) ? format_with_initials(kenshi, group) : normalize_poster_name(kenshi.last_name)
    end
  end

  private_class_method def self.cup_name_groups(kenshis)
    Kenshi.where(cup_id: kenshis.map(&:cup_id).uniq, last_name: kenshis.map(&:last_name).uniq)
      .group_by { |kenshi| [kenshi.cup_id, kenshi.last_name] }
  end

  private_class_method def self.category_name_groups(kenshis, category)
    Kenshi.joins(:participations)
      .where(participations: {category: category})
      .where(last_name: kenshis.map(&:last_name).uniq)
      .distinct
      .group_by(&:last_name)
  end

  private_class_method def self.format_with_initials(kenshi, same_name_group)
    others = same_name_group.reject { |k| k.id == kenshi.id }
    my_initials = single_initials(kenshi.first_name)
    if others.any? { |k| single_initials(k.first_name) == my_initials }
      my_initials = double_initials(kenshi.first_name)
    end
    normalize_poster_name("#{kenshi.last_name} #{my_initials}")
  end

  private_class_method def self.single_initials(first_name)
    first_name.to_s.split(/[\s|-]/).map { |part| "#{part[0]}." }.join
  end

  private_class_method def self.double_initials(first_name)
    first_name.to_s.split(/[\s|-]/).map { |part| "#{part[0, 2]}." }.join
  end

  private_class_method def self.normalize_poster_name(text)
    text.to_s.unicode_normalize(:nfkd).gsub(/[^\x00-\x7F]/n, "").upcase
  end

  def logs
    Rails.logger.debug { "errors: #{errors.inspect}" }
  end

  def fitness
    (grade.to_f / age_at_cup.to_f).round(4)
  end

  def first_name_initials(category: nil)
    initials = first_name.split(/[\s|-]/).map { |s| s.first + "." }.join
    same_name_kenshis = Kenshi.where(last_name:).where.not(id:)
    same_name_kenshis = if category
      same_name_kenshis.includes(:participations).where(participations: {category:})
    else
      same_name_kenshis.where(cup:)
    end
    if same_name_kenshis.exists?
      same_name_kenshis_initials = same_name_kenshis.map do |k|
        k.first_name.split(/[\s|-]/).map { |s| s.first + "." }.join
      end
      if same_name_kenshis_initials.include?(initials)
        initials = first_name.split(/[\s|-]/).map { |s| s[0..1] + "." }.join
      end
    end
    initials
  end

  private def format
    # use POSIX bracket expression here
    self.last_name = last_name.gsub(/[[:alpha:]]+/) { |w| w.capitalize } if last_name
    self.first_name = first_name.to_s.gsub(/[[:alpha:]]+/) { |w| w.capitalize } if first_name
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
