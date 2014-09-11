class User < ActiveRecord::Base
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable and :omniauthable
  devise :database_authenticatable, :registerable, :recoverable, :rememberable, :trackable, :validatable, :confirmable, :omniauthable

  belongs_to :club
  has_many :kenshis, dependent: :destroy

  validates_presence_of :email, unless: lambda{
    Rails.logger.debug "SELF: #{self.inspect}"
    Rails.logger.debug "SELF BLANK?: #{self.uid.blank? && self.provider.blank?}"
    self.uid.blank? && self.provider.blank?
  }
  # validates :email, presence: { unless: :uid? }
  validates :last_name, presence: true, uniqueness: {scope: :first_name,  unless: Proc.new { |u| u.first_name.blank? }}
  validates :first_name, presence: true

  before_validation :format
  # after_save :register_to_mailing_list

  def self.find_for_facebook_oauth(auth, signed_in_resource=nil)
    user = User.where(provider: auth.provider, uid: auth.uid).first
    unless user
      birthday = auth.extra.raw_info.birthday.present? ? Date.strptime(auth.extra.raw_info.birthday, '%m/%d/%Y') : nil
      user = User.new(first_name:auth.extra.raw_info.first_name, last_name:auth.extra.raw_info.last_name, female:(auth.extra.raw_info.gender=='female'), dob:birthday, provider:auth.provider, uid:auth.uid, email:auth.info.email, password:Devise.friendly_token[0,20])
      user.skip_confirmation!
      user.save
      user
    end
    return user
  end

  def club_name
    club.try(:name)
  end

  def club_name=(club_name)
    self.club = Club.find_or_initialize_by name: club_name
  end

  def full_name
    "#{first_name} #{last_name}"
  end

  def registered_for_cup?(cup)
    cup.present? && cup.kenshis.where("kenshis.first_name = ? AND kenshis.last_name = ?", first_name, last_name).present?
  end

  def has_kenshis?
    kenshis.count > 0
  end

  def has_kenshis_for_cup?(cup)
    kenshis.where(cup: cup).count > 0
  end

  def gender
    female? ? '♀' : '♂'
  end

  def fees(currency)
    kenshis.map{|k| k.fees(currency)}.inject{|sum,x| sum + x}
  end

  private

  def format
    self.last_name = self.last_name.gsub(/\w+/){|w| w.capitalize } if self.last_name
    self.first_name = self.first_name.gsub(/\w+/){|w| w.capitalize } if self.first_name
    self.email = self.email.downcase if self.email
  end

  def register_to_mailing_list
    MAILINGLIST.lists.subscribe({id: ENV["MAILCHIMP_LIST_ID"], email: {email: self.email}, merge_vars: {:FNAME => self.first_name, :LNAME => self.last_name}, double_optin: false}) unless ["test"].include?(Rails.env)
  end

  # def self.find_for_twitter_oauth(auth, signed_in_resource=nil)
  #   user = User.where(provider: auth.provider, uid: auth.uid).first
  #   unless user
  #     birthday = auth.extra.raw_info.birthday.present? ? Date.strptime(auth.extra.raw_info.birthday, '%m/%d/%Y') : nil
  #     name = auth.info.name.split(' ')
  #     user = User.new(first_name: name.first, last_name: name.last, dob: birthday, provider: auth.provider, uid: auth.uid, password: Devise.friendly_token[0,20])
  #     user.skip_confirmation!
  #     user.save
  #     Rails.logger.info "AUTH: #{auth.to_yaml}"
  #     Rails.logger.info "USER: #{user.inspect}"
  #     user
  #   end
  #   return user
  # end
end
