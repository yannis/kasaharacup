# frozen_string_literal: true

namespace :temporary do
  namespace :pools do
    desc "Put a cup's team pool encounters on the sides the fight order gives them " \
      "(YEAR=2026, DRY_RUN=1 to only report)"
    task reorient_team_encounters: :environment do
      cup = Cup.find_by!(year: ENV.fetch("YEAR", Date.current.year))
      dry_run = ENV["DRY_RUN"].present?
      puts "Dry run: nothing is written." if dry_run
      puts "Encounters as white × red:"

      cup.team_categories.order(:name).each do |category|
        result = PoolEncounterReorientation.new(category).call(dry_run: dry_run)
        result.swapped.each do |encounter|
          white, red = encounter.team_1&.name, encounter.team_2&.name
          puts "#{category.name} pool #{encounter.pool_number}: #{white} × #{red} -> #{red} × #{white}"
        end
        result.skipped.each do |encounter|
          puts "#{category.name} pool #{encounter.pool_number}: SKIPPED, already scored: " \
            "#{encounter.team_1&.name} × #{encounter.team_2&.name} (encounter #{encounter.id})"
        end
      end
    end
  end
end
