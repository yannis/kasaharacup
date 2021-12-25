# frozen_string_literal: true

class Result < ApplicationRecord
  RESULT_NAMES = ["1", "2", "3", "Fighting spirit"]

  belongs_to :kenshi
  belongs_to :category, polymorphic: true

  validates :name, inclusion: {in: RESULT_NAMES}
end
