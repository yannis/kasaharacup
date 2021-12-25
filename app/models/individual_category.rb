# frozen_string_literal: true

class IndividualCategory < ApplicationRecord
  include ActsAsCategory

  belongs_to :cup, inverse_of: :individual_categories
  has_many :participations, as: :category, dependent: :destroy # inverse_of not working with polymorphic associations
  has_many :kenshis, through: :participations

  delegate :year, to: :cup

  def full_name
    "#{name} (#{cup.year})"
  end
end
