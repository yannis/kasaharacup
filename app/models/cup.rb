# frozen_string_literal: true

require "translate"
class Cup < ApplicationRecord
  has_many :kenshis, inverse_of: :cup, dependent: :destroy
  has_many :participations, through: :kenshis
  has_many :individual_categories, inverse_of: :cup, dependent: :destroy
  has_many :team_categories, inverse_of: :cup, dependent: :destroy
  has_many :teams, through: :team_categories
  has_many :events, inverse_of: :cup, dependent: :destroy
  has_many :headlines, inverse_of: :cup, dependent: :destroy
  has_many :products, inverse_of: :cup, dependent: :destroy

  translate :description

  validates :start_on, presence: true
  validates :deadline, presence: true
  validates :adult_fees_chf, presence: true
  validates :adult_fees_eur, presence: true
  validates :junior_fees_chf, presence: true
  validates :junior_fees_eur, presence: true
  validates :start_on, uniqueness: true

  before_validation :set_deadline, :set_year

  has_one_attached :header_image

  has_one_attached :header_image do |attachable|
    attachable.variant(:thumb, resize_to_fill: [150, 150])
  end

  validate :header_image_is_image

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
    (currency.to_sym == :chf) ? junior_fees_chf : junior_fees_eur
  end

  def adult_fees(currency)
    (currency.to_sym == :chf) ? adult_fees_chf : adult_fees_eur
  end

  def canceled?
    canceled_at.present?
  end

  def registerable?
    !past? &&
      !canceled? &&
      deadline >= Time.current &&
      (registerable_at.blank? || registerable_at < Time.current)
  end

  def not_yet_registerable?
    !past? &&
      !canceled? &&
      registerable_at.present? && registerable_at > Time.current
  end

  private def set_deadline
    self.deadline = (start_on.to_time - 7.days) if start_on.present? && deadline.blank?
  end

  private def set_year
    if year.blank?
      self.year = start_on.try(:year)
    end
  end

  private def header_image_is_image
    return if header_image.blob.nil? || header_image.blob&.content_type&.start_with?("image/")

    header_image.purge
    errors.add(:header_image, "must be an image")
  end
end
