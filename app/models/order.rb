# frozen_string_literal: true

class Order < ApplicationRecord
  belongs_to :user
  belongs_to :cup
  has_many :purchases
  has_many :products, through: :purchases
end
