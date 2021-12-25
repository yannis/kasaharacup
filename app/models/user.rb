# frozen_string_literal: true

class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable,
    :recoverable, :rememberable, :validatable
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable,
    :recoverable, :rememberable, :validatable
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable,
    :recoverable, :rememberable, :validatable
  belongs_to :club
  has_many :kenshis, dependent: :destroy

  validates :email, presence: {unless: lambda {
    # Rails.logger.debug "SELF: #{self.inspect}"
    # Rails.logger.debug "SELF BLANK?: #{self.uid.blank? && self.provider.blank?}"
    uid.blank? && provider.blank?
  }}
  # validates :email, presence: { unless: :uid? }
  validates :last_name, presence: true, uniqueness: {scope: :first_name, unless: proc { |u|
                                                                                   u.first_name.blank?
                                                                                 }}
  validates :first_name, presence: true

  before_validation :format

  def club_name=(club_name)
    self.club = Club.find_or_initialize_by name: club_name
  end

  def club_name
    club.try(:name)
  end

  def full_name
    "#{first_name} #{last_name}"
  end

  def registered_for_cup?(cup)
    cup.present? && cup.kenshis.where("kenshis.first_name = ? AND kenshis.last_name = ?", first_name,
      last_name).present?
  end

  def has_kenshis?
    kenshis.count > 0
  end

  def has_kenshis_for_cup?(cup)
    kenshis.where(cup: cup).count > 0
  end

  def gender
    female? ? "♀" : "♂"
  end

  def fees(currency, cup)
    kenshis.for_cup(cup).map { |k| k.fees(currency) }.inject { |sum, x| sum + x }
  end

  private def format
    # use POSIX bracket expression here
    self.last_name = last_name.gsub(/[[:alpha:]]+/) { |w| w.capitalize } if last_name
    self.first_name = first_name.mb_chars.gsub(/[[:alpha:]]+/) { |w| w.capitalize } if first_name
    self.email = email.downcase if email
  end
end
