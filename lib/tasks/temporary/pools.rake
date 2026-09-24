# frozen_string_literal: true

namespace :temporary do
  namespace :pools do
    desc "Put a cup's already drawn pools in the fight order and on its sides " \
      "(YEAR=2026, DRY_RUN=1 to only report)"
    task reorient: :environment do
      cup = Cup.find_by!(year: ENV.fetch("YEAR", Date.current.year))
      dry_run = ENV["DRY_RUN"].present?
      puts "Dry run: nothing is written." if dry_run

      puts "Team encounters, as white × red:"
      cup.team_categories.order(:name).each do |category|
        result = PoolEncounterReorientation.new(category).call(dry_run: dry_run)
        result.swapped.each do |encounter|
          white, red = encounter.team_1&.name, encounter.team_2&.name
          puts "  #{category.name} pool #{encounter.pool_number}: #{white} × #{red} -> #{red} × #{white}"
        end
        result.skipped.each do |encounter|
          puts "  #{category.name} pool #{encounter.pool_number}: SKIPPED, already scored: " \
            "#{encounter.team_1&.name} × #{encounter.team_2&.name} (encounter #{encounter.id})"
        end
      end

      puts "Individual fights:"
      cup.individual_categories.order(:name).each do |category|
        result = PoolFightReorientation.new(category).call(dry_run: dry_run)
        result.reordered.each { |number| puts "  #{category.name} pool #{number}: reordered" }
        result.skipped.each do |number|
          puts "  #{category.name} pool #{number}: SKIPPED, a fight is scored or no longer matches the pool"
        end
      end
    end
  end
end
