# frozen_string_literal: true

class AddFightingSpiritToParticipations < ActiveRecord::Migration[7.0]
  def change
    add_column :participations, :fighting_spirit, :boolean, default: :false
  end
end
