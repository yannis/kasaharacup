# frozen_string_literal: true

require_relative "../results/add_results"
namespace :temporary do
  namespace :cups do
    desc "Add 2023"
    task add_2023: :environment do
      include AddResults

      events_data = [
        {
          name_en: "Kyu gradings (only for members of Swiss Kendo Federation)",
          name_fr: "Examens de Kyu (seulement pour les membres de la fédération Suisse de Kendo)",
          start_on: "2023-09-23 09:30:00"
        },
        {
          name_en: "Check-in and shinais check",
          name_fr: "Accueil et contôle des shinais",
          start_on: "2023-09-23 11:30:00"
        },
        {
          name_en: "Team competition",
          name_fr: "Compétition par équipe",
          start_on: "2023-09-23 13:00"
        },
        {
          name_en: "Free jigeiko",
          name_fr: "Jigeiko libre",
          start_on: "2023-09-23 18:00:00"
        },
        {
          name_en: "Saturday dinner",
          name_fr: "Dîner du samedi",
          start_on: "2023-09-23 20:00:00"
        },
        {
          name_en: "Breakfast",
          name_fr: "Petit-déjeuner",
          start_on: "2023-09-24 07:15:00"
        },
        {
          name_en: "Individual competition (open, ladies and juniors)",
          name_fr: "Compétition en individuel (open, ladies et juniors)",
          start_on: "2023-09-24 08:30:00"
        },
        {
          name_en: "Lunch break",
          name_fr: "Pause déjeuner",
          start_on: "2023-09-24 12:00:00"
        },
        {
          name_en: "Finals and ending",
          name_fr: "Finales et clôture",
          start_on: "2023-09-24 16:30:00"
        }
      ]

      products_data = [
        {
          name_en: "Participation Junior (17-)",
          name_fr: "Participation Junior (17-)",
          fee_chf: 20,
          fee_eu: 20
        },
        {
          name_en: "Participation Adult (18+)",
          name_fr: "Participation Adult (18+)",
          fee_chf: 30,
          fee_eu: 30
        },
        {
          name_en: "2 Kyu examination",
          name_fr: "Examen de 2 Kyu",
          fee_chf: 20,
          fee_eu: 20
        },
        {
          name_en: "1 Kyu examination",
          name_fr: "Examen de 1 Kyu",
          fee_chf: 30,
          fee_eu: 30
        },
        {
          name_en: "Saturday dinner",
          name_fr: "Dîner du samedi",
          fee_chf: 30,
          fee_eu: 30,
          quota: 90
        },
        {
          name_en: "Sunday lunch - sandwich menu",
          name_fr: "Lunch du dimanche - menu sandwich",
          fee_chf: 10,
          fee_eu: 10
        },
        {
          name_en: "Night at the dormitory (Friday)",
          name_fr: "Nuit au dortoir (Vendredi)",
          fee_chf: 25,
          fee_eu: 25,
          quota: 50
        },
        {
          name_en: "Night at the dormitory (Saturday)",
          name_fr: "Nuit au dortoir (Samedi)",
          fee_chf: 25,
          fee_eu: 25,
          quota: 50
        },
        {
          name_en: "Night at the dormitory (Sunday)",
          name_fr: "Nuit au dortoir (Dimanche)",
          fee_chf: 25,
          fee_eu: 25,
          quota: 50
        }
      ]

      individual_categories_data = [
        {
          name: "Junior U15",
          pool_size: 3,
          out_of_pool: 2,
          min_age: 12,
          max_age: 14,
          description_en: "Born in #{2023 - 14}, #{2023 - 13} or #{2023 - 12}",
          description_fr: "Né(e) en #{2023 - 14}, #{2023 - 13} ou #{2023 - 12}"
        },
        {
          name: "Junior U18",
          pool_size: 3,
          out_of_pool: 2,
          min_age: 15,
          max_age: 17,
          description_en: "Born in #{2023 - 17}, #{2023 - 16} or #{2023 - 15}",
          description_fr: "Né(e) en #{2023 - 17}, #{2023 - 16} or #{2023 - 15}"
        },
        {
          name: "Open",
          pool_size: 3,
          out_of_pool: 2,
          min_age: 17,
          max_age: nil,
          description_en: "Born in #{2023 - 18} or before",
          description_fr: "Né(e) en #{2023 - 18} ou avant"
        },
        {
          name: "Ladies",
          pool_size: 3,
          out_of_pool: 2,
          min_age: 17,
          max_age: nil,
          description_en: "Born in #{2023 - 18} or before",
          description_fr: "Née en #{2023 - 18} ou avant"
        }
      ]

      team_categories_data = [
        {
          name: "Team",
          pool_size: nil,
          out_of_pool: nil,
          min_age: 17,
          max_age: nil,
          description_en: "Born in #{2023 - 16} or before.
          Participants born in #{2023 - 16}
          and #{2023 - 17} will be required to show a document signed by a legal representative".squish,
          description_fr: "Né(e) en #{2023 - 16} ou avant.
          Les participants nés en #{2023 - 16}
          et #{2023 - 17} devront présenter une décharge signée par un représentant légal".squish
        }
      ]

      ActiveRecord::Base.transaction do
        cup = Cup.find_by(start_on: "2023-09-23")
        create_header_image(cup: cup, image: "kasa-2023.jpeg")
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
