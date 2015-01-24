class Cup < ActiveRecord::Base
  has_many :kenshis, inverse_of: :cup, dependent: :destroy
  has_many :individual_categories, inverse_of: :cup, dependent: :destroy
  has_many :team_categories, inverse_of: :cup, dependent: :destroy
  has_many :events, inverse_of: :cup, dependent: :destroy
  has_many :headlines, inverse_of: :cup, dependent: :destroy
  has_many :products, inverse_of: :cup, dependent: :destroy

  validates_presence_of :start_on
  validates_presence_of :published_on
  validates_presence_of :deadline
  validates_presence_of :adult_fees_chf
  validates_presence_of :adult_fees_eur
  validates_presence_of :junior_fees_chf
  validates_presence_of :junior_fees_eur
  validates_uniqueness_of :start_on
  validates_uniqueness_of :published_on

  before_validation :set_deadline

  def to_param
    year
  end

  def to_s
    year.to_s
  end

  def year
    start_on.year
  end

  def dates
    startd = start_on.day
    endd = (end_on.presence || start_on+1.day).strftime('%d %B')
    return "#{startd}-#{endd}"
  end

  def junior_fees(currency)
    currency.to_sym == :chf ? self.junior_fees_chf : self.junior_fees_eur
  end

  def adult_fees(currency)
    currency.to_sym == :chf ? self.adult_fees_chf : self.adult_fees_eur
  end

  def published?
    !published_on || published_on <= Date.today
  end

  private

    def set_deadline
      self.deadline = (self.start_on.to_time-7.days) if self.start_on.present? && self.deadline.blank?
    end
end
