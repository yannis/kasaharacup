# frozen_string_literal: true

class AddTermsAcceptedAtToKenshis < ActiveRecord::Migration[8.1]
  def change
    add_column :kenshis, :terms_accepted_at, :datetime
  end
end
