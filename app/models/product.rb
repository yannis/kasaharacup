# frozen_string_literal: true

require "translate"
class Product < ApplicationRecord
  belongs_to :cup
  belongs_to :event, optional: true
  has_many :purchases, dependent: :destroy, autosave: true
  has_many :kenshis, through: :purchases

  validates :name_en, presence: true, uniqueness: {scope: :cup_id}
  validates :name_fr, presence: true, uniqueness: {scope: :cup_id}
  validates :fee_chf, presence: true, numericality: {allow_nil: true}
  validates :fee_eu, presence: true, numericality: {allow_nil: true}

  translate :name, :description

  delegate :year, to: :cup
end
