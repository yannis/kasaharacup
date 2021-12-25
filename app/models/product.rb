# frozen_string_literal: true

require "translate"
class Product < ApplicationRecord
  belongs_to :cup
  belongs_to :event
  has_many :purchases, dependent: :destroy, autosave: true
  has_many :kenshis, through: :purchases

  validates :name_en, presence: true
  validates :name_fr, presence: true
  validates :name_de, presence: true
  validates :name_en, uniqueness: {scope: :cup_id}
  validates :name_fr, uniqueness: {scope: :cup_id}
  validates :name_de, uniqueness: {scope: :cup_id}
  validates :fee_chf, presence: true
  validates :fee_eu, presence: true
  validates :fee_chf, numericality: {allow_nil: true}
  validates :fee_eu, numericality: {allow_nil: true}

  translate :name, :description

  delegate :year, to: :cup
end
