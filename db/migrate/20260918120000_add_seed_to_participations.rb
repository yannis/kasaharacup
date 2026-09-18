# frozen_string_literal: true

# Individual categories get the seeding teams already have. Mirrors teams.seed
# (1 = champion … 4 = fourth medal); SmartPooler pins the seeded into pools
# that feed opposite halves of the bracket.
#
# No index: every path that reads seeds has already loaded the category's
# participations in full, and teams.seed carries none either.
#
# participations is polymorphic, so the column lands on team-category
# participations too, where it means nothing — a team's seed lives on the team.
class AddSeedToParticipations < ActiveRecord::Migration[8.1]
  def change
    add_column :participations, :seed, :integer
  end
end
