# frozen_string_literal: true

namespace :temporary do
  namespace :cups do
    desc "Cancel 2021"
    task cancel_2021: :environment do
      ActiveRecord::Base.transaction do
        cup = Cup.find_by!(year: 2021)
        cup.update!(canceled_at: 1.years.ago)
      end
    end
  end
end
