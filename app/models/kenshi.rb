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

  # Normalized on assignment rather than in a before_validation, so the value
  # the uniqueness check and every hash finder see is the one the database will
  # hold: a stray space used to slip a duplicate past them, and to leave a
  # family name unmatched by its namesakes — which is how two Ito printed with
  # no disambiguating initial (#1293). POSIX bracket expression, so an accented
  # letter counts as a letter.
  normalizes :first_name, :last_name, with: ->(name) {
    name.squish.gsub(/[[:alpha:]]+/) { |word| word.capitalize }
  }
  normalizes :email, with: ->(email) { email.strip.downcase }

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

  # Sorted in Ruby so a preloaded `purchases: :product` is read in memory: the
  # same list ordered in SQL joins products again, once per kenshi on a page
  # that shows several. A product with no position sorts last, as ORDER BY
  # products.position does.
  def ordered_purchases
    purchases.sort_by { |purchase| [purchase.product.position ? 0 : 1, purchase.product.position || 0] }
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

  # The name printed on posters, brackets and match sheets: the family name
  # alone, or the family name followed by enough of the first name to tell
  # namesakes apart.
  def poster_name(category: nil)
    Kenshi.poster_names_for([self], category:)[id]
  end

  # Just the first-name part of a poster name, for listings that print the
  # family name in a column of their own.
  def first_name_initials(category: nil)
    Kenshi.first_name_initials_for([self], category:)[id]
  end

  # Batch-computes poster_name for a collection of kenshis with a single DB
  # query, avoiding the N+1 that calling #poster_name in a loop produces.
  # Returns a hash {kenshi.id => poster_name}. Namesake disambiguation is
  # cup-scoped by default, matching #poster_name; pass a category to scope it to
  # that category's participants, matching #poster_name(category:).
  def self.poster_names_for(kenshis, category: nil)
    return {} if kenshis.empty?

    groups = namesake_groups(kenshis, category:)

    kenshis.each_with_object({}) do |kenshi, hash|
      namesakes = namesakes_of(kenshi, groups, category:)
      hash[kenshi.id] = if namesakes.empty?
        normalize_poster_name(kenshi.last_name)
      else
        normalize_poster_name("#{kenshi.last_name} #{initials_among(kenshi, namesakes)}")
      end
    end
  end

  # The same initials #first_name_initials gives, for a whole collection in one
  # query rather than one per kenshi. Returns a hash {kenshi.id => initials}.
  def self.first_name_initials_for(kenshis, category: nil)
    return {} if kenshis.empty?

    groups = namesake_groups(kenshis, category:)

    kenshis.to_h { |kenshi| [kenshi.id, initials_among(kenshi, namesakes_of(kenshi, groups, category:))] }
  end

  # Namesakes are matched on the name the reader actually sees, not on the one
  # stored: spellings that differ only by case, by an accent or by a stray space
  # print identically, so they have to disambiguate each other. No SQL equality
  # says that, so the whole scope is fetched once and grouped in Ruby.
  private_class_method def self.namesake_groups(kenshis, category:)
    scope = if category
      joins(:participations).where(participations: {category:}).distinct
    else
      where(cup_id: kenshis.map(&:cup_id).uniq)
    end

    scope.select(:id, :cup_id, :first_name, :last_name)
      .group_by { |candidate| namesake_key(candidate, category:) }
  end

  # A category scope holds a single cup's participants, so the printed family
  # name alone identifies the group there; a cup scope may span several.
  private_class_method def self.namesake_key(kenshi, category:)
    printed = normalize_poster_name(kenshi.last_name)
    category ? printed : [kenshi.cup_id, printed]
  end

  private_class_method def self.namesakes_of(kenshi, groups, category:)
    groups.fetch(namesake_key(kenshi, category:), []).reject { |other| other.id == kenshi.id }
  end

  # One letter is usually enough; a namesake whose first name prints the same
  # initial pushes both of them to two.
  private_class_method def self.initials_among(kenshi, namesakes)
    initials = single_initials(kenshi.first_name)
    taken = namesakes.map { |other| normalize_poster_name(single_initials(other.first_name)) }
    return double_initials(kenshi.first_name) if taken.include?(normalize_poster_name(initials))

    initials
  end

  private_class_method def self.single_initials(first_name)
    name_parts(first_name).map { |part| "#{part[0]}." }.join
  end

  private_class_method def self.double_initials(first_name)
    name_parts(first_name).map { |part| "#{part[0, 2]}." }.join
  end

  private_class_method def self.name_parts(first_name)
    first_name.to_s.split(/[\s|-]+/).reject(&:empty?)
  end

  private_class_method def self.normalize_poster_name(text)
    text.to_s.unicode_normalize(:nfkd).gsub(/[^\x00-\x7F]/, "").upcase.squish
  end

  def logs
    Rails.logger.debug { "errors: #{errors.inspect}" }
  end

  def fitness
    (grade.to_f / age_at_cup.to_f).round(4)
  end

  private def notify_slack
    notification = Slack::Notifications::Registration.new(self)
    Slack::NotificationService.new.call(notification: notification)
  end

  private def update_purchase
    Kenshis::CalculatePurchasesService.new(kenshi: self).call
  end
end
