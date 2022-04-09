# frozen_string_literal: true

class Document < ApplicationRecord
  belongs_to :category, polymorphic: true

  has_one_attached :file

  validate :check_file_type

  private def check_file_type
    if file.attached? && !file.content_type.in?(%w[application/pdf])
      file.purge # delete the uploaded file
      errors.add(:file, "Must be a PDF file")
    end
  end
end
