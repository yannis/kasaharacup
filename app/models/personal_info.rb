# frozen_string_literal: true

class PersonalInfo < ApplicationRecord
  enum document_type: {passport: "passport", id_card: "id_card"}

  encrypts :residential_address, :residential_zip_code, :residential_city,
    :residential_phone_number, :document_number, :email

  belongs_to :kenshi, inverse_of: :personal_info

  validates :residential_phone_number, presence: true
  validates :residential_address, presence: true
  validates :residential_zip_code, presence: true
  validates :residential_city, presence: true
  validates :residential_country, presence: true, inclusion: {in: ISO3166::Country.all.map(&:alpha2), allow_blank: true}
  validates :origin_country, presence: true, inclusion: {in: ISO3166::Country.all.map(&:alpha2), allow_blank: true}
  validates :document_type, presence: true, inclusion: {in: document_types.keys, allow_blank: true}
  validates :document_number, presence: true
  validates :email, presence: true, format: {with: Devise.email_regexp, allow_blank: true}
end
