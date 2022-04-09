# frozen_string_literal: true

require_relative "add_results"
namespace :temporary do
  namespace :cups do
    desc "Add past results, documents and videos"
    task add: :environment do
      include AddResults

      clean_kenshis
      clean_teams
      ActiveRecord::Base.transaction do
        Rake::Task["temporary:cups:add_2014"].invoke
        Rake::Task["temporary:cups:add_2015"].invoke
        Rake::Task["temporary:cups:add_2016"].invoke
        Rake::Task["temporary:cups:add_2017"].invoke
        Rake::Task["temporary:cups:add_2018"].invoke
        Rake::Task["temporary:cups:add_2019"].invoke
      end
    end
  end
end
