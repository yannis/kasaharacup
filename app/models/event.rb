# frozen_string_literal: true

require "translate"
class Event < ApplicationRecord
  belongs_to :cup

  validates :name_en, presence: true
  validates :name_fr, presence: true
  validates :start_on, presence: true

  delegate :year, to: :cup

  translate :name
end
