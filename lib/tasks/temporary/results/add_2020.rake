# frozen_string_literal: true

namespace :temporary do
  namespace :cups do
    desc "Cancel 2020"
    task cancel_2020: :environment do
      ActiveRecord::Base.transaction do
        cup = Cup.find_by!(year: 2020)
        cup.update!(canceled_at: 2.years.ago)
      end
    end
  end
end
