# frozen_string_literal: true

namespace :temporary do
  namespace :cups do
    desc "Add 2022"
    task add_2022: :environment do
      cup_data = {
        start_on: Date.parse("2022-09-24"),
        end_on: Date.parse("2022-09-25"),
        junior_fees_chf: 20,
        junior_fees_eur: 20,
        adult_fees_chf: 30,
        adult_fees_eur: 30
      }

      events_data = [
        {
          name_en: "Kyu gradings (only for members of Swiss Kendo Federation)",
          name_fr: "Examens de Kyu (seulement pour les membres de la fédération Suisse de Kendo)",
          start_on: "2022-09-24 09:30:00"
        },
        {
          name_en: "Check-in and shinais check",
          name_fr: "Accueil et contôle des shinais",
          start_on: "2022-09-24 11:30:00"
        },
        {
          name_en: "Team competition",
          name_fr: "Compétition par équipe",
          start_on: "2022-09-24 12:30:00"
        },
        {
          name_en: "Free jigeiko",
          name_fr: "Jigeiko libre",
          start_on: "2022-09-24 18:00:00"
        },
        {
          name_en: "Dinner",
          name_fr: "Dîner",
          start_on: "2022-09-24 20:00:00"
        },
        {
          name_en: "Breakfast",
          name_fr: "Petit-déjeuner",
          start_on: "2022-09-25 07:15:00"
        },
        {
          name_en: "Individual competition (open, ladies and juniors)",
          name_fr: "Compétition en individuel (open, ladies et juniors)",
          start_on: "2022-09-25 08:30:00"
        },
        {
          name_en: "Lunch break",
          name_fr: "Pause déjeuner",
          start_on: "2022-09-25 12:00:00"
        },
        {
          name_en: "Finals and ending",
          name_fr: "Finales et clôture",
          start_on: "2022-09-25 17:00:00"
        }
      ]

      products_data = [
        {
          name_en: "Kyu examination",
          name_fr: "Examen de kyu",
          description_en: "Variable price",
          description_fr: "Prix variable",
          fee_chf: 0,
          fee_eu: 0
        },
        {
          name_en: "Dinner",
          name_fr: "Dîner",
          fee_chf: 30,
          fee_eu: 27
        },
        {
          name_en: "Night at the dormitory",
          name_fr: "Nuit au dortoir",
          fee_chf: 25,
          fee_eu: 23
        }
      ]

      individual_categories_data = [
        {
          name: "Junior U12",
          pool_size: 3,
          out_of_pool: 2,
          min_age: nil,
          max_age: 12,
          description_en: "Born in #{2022 - 11} or after",
          description_fr: "Né(e) en #{2022 - 11} ou après"
        },
        {
          name: "Junior U15",
          pool_size: 3,
          out_of_pool: 2,
          min_age: 12,
          max_age: 14,
          description_en: "Born in #{2022 - 14}, #{2022 - 13} or #{2022 - 12}",
          description_fr: "Né(e) en #{2022 - 14}, #{2022 - 13} ou #{2022 - 12}"
        },
        {
          name: "Junior U18",
          pool_size: 3,
          out_of_pool: 2,
          min_age: 15,
          max_age: 17,
          description_en: "Born in #{2022 - 17}, #{2022 - 16} or #{2022 - 15}",
          description_fr: "Né(e) en #{2022 - 17}, #{2022 - 16} ou #{2022 - 15}"
        },
        {
          name: "Open",
          pool_size: 3,
          out_of_pool: 2,
          min_age: 17,
          max_age: nil,
          description_en: "Born in #{2022 - 18} or before",
          description_fr: "Né(e) en #{2022 - 18} ou avant"
        },
        {
          name: "Ladies",
          pool_size: 3,
          out_of_pool: 2,
          min_age: 17,
          max_age: nil,
          description_en: "Born in #{2022 - 18} or before",
          description_fr: "Née en #{2022 - 18} ou avant"
        }
      ]

      team_categories_data = [
        {
          name: "Team",
          pool_size: nil,
          out_of_pool: nil,
          min_age: 17,
          max_age: nil,
          description_en: "Born in #{2022 - 17} or before.
          Participants born in #{2022 - 17} will be required to show a document signed by a legal representative",
          description_fr: "Né(e) en #{2022 - 17} ou avant.
          Les participants né en #{2022 - 17} devront présenter une décharge signée par un représentant légal"
        }
      ]

      ActiveRecord::Base.transaction do
        cup = Cup.create!(cup_data)
        events_data.each do |event_data|
          cup.events.create!(event_data)
        end
        products_data.each do |product_data|
          cup.products.create!(product_data)
        end
        individual_categories_data.each do |individual_category_data|
          cup.individual_categories.create!(individual_category_data)
        end
        team_categories_data.each do |team_category_data|
          cup.team_categories.create!(team_category_data)
        end
      end
    end
  end
end
