# frozen_string_literal: true

class Cup < ApplicationRecord
  has_many :kenshis, inverse_of: :cup, dependent: :destroy
  has_many :participations, through: :kenshis
  has_many :individual_categories, inverse_of: :cup, dependent: :destroy
  has_many :team_categories, inverse_of: :cup, dependent: :destroy
  has_many :teams, through: :team_categories
  has_many :events, inverse_of: :cup, dependent: :destroy
  has_many :headlines, inverse_of: :cup, dependent: :destroy
  has_many :products, inverse_of: :cup, dependent: :destroy

  validates :start_on, presence: true
  validates :deadline, presence: true
  validates :adult_fees_chf, presence: true
  validates :adult_fees_eur, presence: true
  validates :junior_fees_chf, presence: true
  validates :junior_fees_eur, presence: true
  validates :start_on, uniqueness: true

  before_validation :set_deadline, :set_year

  def self.past
    where("cups.start_on < ?", Date.current)
  end

  def self.future
    where("cups.start_on >= ?", Date.current)
  end

  def to_param
    year
  end

  delegate :to_s, to: :year

  def past?
    start_on < Date.current
  end

  def junior_fees(currency)
    currency.to_sym == :chf ? junior_fees_chf : junior_fees_eur
  end

  def adult_fees(currency)
    currency.to_sym == :chf ? adult_fees_chf : adult_fees_eur
  end

  def canceled?
    canceled_at.present?
  end

  private def set_deadline
    self.deadline = (start_on.to_time - 7.days) if start_on.present? && deadline.blank?
  end

  private def set_year
    if year.blank?
      self.year = start_on.try(:year)
    end
  end
end
