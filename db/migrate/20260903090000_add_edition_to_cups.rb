# frozen_string_literal: true

class AddEditionToCups < ActiveRecord::Migration[8.1]
  # Editions held between the first cup (1984) and the earliest one recorded in
  # this database (2014). Anchored on the two edition numbers the about page has
  # always quoted: the 33rd edition in 2019 and the 34th in 2022.
  EDITIONS_BEFORE_FIRST_RECORDED = 27

  def up
    add_column :cups, :edition, :integer

    edition = EDITIONS_BEFORE_FIRST_RECORDED
    Cup.reset_column_information
    Cup.order(:start_on).each do |cup|
      next if cup.canceled_at.present?

      edition += 1
      cup.update_column(:edition, edition)
    end
  end

  def down
    remove_column :cups, :edition
  end
end
