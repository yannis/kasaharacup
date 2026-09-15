# frozen_string_literal: true

# Kenshi names were stored as typed until #1293, stray spaces included. A name
# with a leading space printed with that space on the poster and, worse, never
# matched its namesakes, so neither of them got a disambiguating initial.
# Kenshi#format squishes on save from now on; these are the rows that predate
# it.
class SquishKenshiNames < ActiveRecord::Migration[8.1]
  SQUISHED = "btrim(regexp_replace(%s, '[[:space:]]+', ' ', 'g'))"

  def up
    first_name, last_name = [SQUISHED % "first_name", SQUISHED % "last_name"]

    execute(<<~SQL.squish)
      UPDATE kenshis
      SET first_name = #{first_name}, last_name = #{last_name}
      WHERE first_name <> #{first_name} OR last_name <> #{last_name}
    SQL
  end

  # Irreversible on purpose: the removed whitespace is not recorded anywhere,
  # and nothing downstream wants it back.
  def down
  end
end
