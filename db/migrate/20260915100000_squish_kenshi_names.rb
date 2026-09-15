# frozen_string_literal: true

# Kenshi names were stored as typed until #1293: stray spaces and whatever
# capitalization the registrant used. A name with a leading space printed with
# that space on the poster and, worse, never matched its namesakes, so neither
# of them got a disambiguating initial.
#
# `normalizes :first_name, :last_name` (app/models/kenshi.rb) now squishes and
# capitalizes on assignment, and normalizes the values of hash finders with it —
# so a row that does not already hold its normalized form is unreachable by
# every such finder, the uniqueness check included. These are the rows that
# predate the declaration.
#
# Deliberately driven through Kenshi.normalize_value_for rather than an
# equivalent written in SQL: the point is for the data to match the rule the
# model declares, and `initcap` is not that rule (it treats digits as word
# characters, where [[:alpha:]] does not).
class SquishKenshiNames < ActiveRecord::Migration[8.1]
  def up
    check_for_collisions!

    Kenshi.find_each do |kenshi|
      normalized = normalize(kenshi)
      next if normalized.all? { |attribute, value| kenshi[attribute] == value }

      # #update_columns writes through the normalizing attribute type, so it
      # applies the very rule this migration exists to enforce, and skips the
      # validations and callbacks that a legacy row has no business running.
      kenshi.update_columns(normalized)
    end
  end

  # Irreversible: the stray whitespace and the original capitalization are not
  # recorded anywhere, and nothing downstream wants them back.
  def down
    raise ActiveRecord::IrreversibleMigration
  end

  private def normalize(kenshi)
    {
      first_name: Kenshi.normalize_value_for(:first_name, kenshi.first_name),
      last_name: Kenshi.normalize_value_for(:last_name, kenshi.last_name)
    }
  end

  # (cup_id, first_name, last_name) is unique, and the whole reason these rows
  # exist is that an unnormalized name slipped past the uniqueness validation —
  # so normalizing can collapse two rows onto one key. Checked up front, before
  # anything is written: a mid-UPDATE PG::UniqueViolation would abort the
  # release phase with nothing but a constraint name, where this names the rows
  # to merge and leaves the table untouched.
  private def check_for_collisions!
    collisions = Kenshi.select(:id, :cup_id, :first_name, :last_name)
      .group_by { |kenshi| [kenshi.cup_id, *normalize(kenshi).values] }
      .select { |_, kenshis| kenshis.size > 1 }

    return if collisions.empty?

    raise <<~MESSAGE
      Normalizing kenshi names would violate index_kenshis_on_cup_id_and_first_name_and_last_name.
      Merge or rename these rows, then migrate again:
      #{collisions.map { |(cup_id, first_name, last_name), kenshis|
        "  cup #{cup_id} #{first_name} #{last_name}: ids #{kenshis.map(&:id).inspect}"
      }.join("\n")}
    MESSAGE
  end
end
