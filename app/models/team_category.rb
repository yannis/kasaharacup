# frozen_string_literal: true

class TeamCategory < ApplicationRecord
  include ActsAsCategory

  belongs_to :cup, inverse_of: :team_categories
  has_many :teams, inverse_of: :team_category, dependent: :destroy
  has_many :participations, as: :category, dependent: :destroy
  has_many :videos, as: :category, dependent: :destroy
  has_many :documents, as: :category, dependent: :destroy
  has_many :kenshis, through: :teams

  delegate :year, to: :cup

  def full_name
    "#{name} (#{cup.year})"
  end
end
