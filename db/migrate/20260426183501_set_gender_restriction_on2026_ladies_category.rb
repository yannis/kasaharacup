# frozen_string_literal: true

class SetGenderRestrictionOn2026LadiesCategory < ActiveRecord::Migration[8.1]
  def up
    cup_id = execute("SELECT id FROM cups WHERE year = 2026 LIMIT 1").first&.fetch("id")
    return unless cup_id

    execute(<<~SQL.squish)
      UPDATE individual_categories
      SET gender_restriction = 'female'
      WHERE cup_id = #{cup_id.to_i}
        AND name = 'Ladies'
        AND gender_restriction IS NULL
    SQL
  end

  def down
    cup_id = execute("SELECT id FROM cups WHERE year = 2026 LIMIT 1").first&.fetch("id")
    return unless cup_id

    execute(<<~SQL.squish)
      UPDATE individual_categories
      SET gender_restriction = NULL
      WHERE cup_id = #{cup_id.to_i}
        AND name = 'Ladies'
        AND gender_restriction = 'female'
    SQL
  end
end
