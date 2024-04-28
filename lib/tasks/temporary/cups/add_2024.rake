# frozen_string_literal: true

require_relative "../results/add_results"

namespace :temporary do
  namespace :cups do
    desc "Add 2024"
    task add_2024: :environment do
      include AddResults

      events_data = [
        {
          name_en: "Kyu gradings (only for members of Swiss Kendo Federation)",
          name_fr: "Examens de Kyu (seulement pour les membres de la Fédération Suisse de Kendo)",
          start_on: "2024-09-28 09:30:00"
        },
        {
          name_en: "Check-in and shinai check",
          name_fr: "Accueil et contrôle des shinais",
          start_on: "2024-09-28 11:30:00"
        },
        {
          name_en: "Opening ceremony",
          name_fr: "Cérémonie d'ouverture",
          start_on: "2024-09-28 13:00"
        },
        {
          name_en: "Team competition",
          name_fr: "Compétition par équipe",
          start_on: "2024-09-28 13:15"
        },
        {
          name_en: "Free jigeiko",
          name_fr: "Jigeiko libre",
          start_on: "2024-09-28 18:00:00"
        },
        {
          name_en: "Dinner",
          name_fr: "Dîner",
          start_on: "2024-09-28 20:00:00"
        },
        {
          name_en: "Breakfast for those sleeping in the dormitory",
          name_fr: "Petit-déjeuner pour ceux qui dorment au dortoir",
          start_on: "2024-09-29 07:15:00"
        },
        {
          name_en: "Shinai check",
          name_fr: "Contrôle des shinais",
          start_on: "2024-09-29 07:30:00"
        },
        {
          name_en: "Opening ceremony",
          name_fr: "Cérémonie d'ouverture",
          start_on: "2024-09-29 08:15:00"
        },
        {
          name_en: "Individual competitions (open, ladies and juniors)",
          name_fr: "Compétitions individuelles (open, dames et juniors)",
          start_on: "2024-09-29 08:30:00"
        },
        {
          name_en: "Lunch break",
          name_fr: "Pause déjeuner",
          start_on: "2024-09-29 12:00:00"
        },
        {
          name_en: "Finals and ending",
          name_fr: "Finales et clôture",
          start_on: "2024-09-29 16:30:00"
        }
      ]

      products_data = [
        {
          name_en: "Participation Team",
          name_fr: "Participation Team",
          fee_chf: 20,
          fee_eu: 20,
          position: 1,
          display: false
        },
        {
          name_en: "Participation Individuals Junior (17 years old and younger)",
          name_fr: "Participation Individuels Junior (17 ans et moins)",
          fee_chf: 15,
          fee_eu: 15,
          position: 1,
          display: false
        },
        {
          name_en: "Participation Individuals Adult (18 years old and older)",
          name_fr: "Participation Individuels Adulte (18 ans et plus)",
          fee_chf: 25,
          fee_eu: 25,
          position: 2,
          display: false
        },
        {
          name_en: "Participation 2 Days Junior (17 years old and younger)",
          name_fr: "Participation 2 Jours Junior (17 ans et moins)",
          fee_chf: 25,
          fee_eu: 25,
          position: 2,
          display: false
        },
        {
          name_en: "Participation 2 Days Adult (18 years old and older)",
          name_fr: "Participation 2 Jours Adulte (18 ans et plus)",
          fee_chf: 40,
          fee_eu: 40,
          position: 2,
          display: false
        },
        {
          name_en: "Saturday dinner",
          name_fr: "Dîner du samedi",
          fee_chf: 25,
          fee_eu: 25,
          quota: 90,
          position: 3
        },
        {
          name_en: "Sunday lunch - sandwich menu",
          name_fr: "Lunch du dimanche - menu sandwich",
          fee_chf: 15,
          fee_eu: 15,
          position: 4
        },
        {
          name_en: "Night at the dormitory (Friday)",
          name_fr: "Nuit au dortoir (Vendredi)",
          fee_chf: 27,
          fee_eu: 27,
          quota: 40,
          position: 5,
          require_personal_infos: true
        },
        {
          name_en: "Night at the dormitory (Saturday)",
          name_fr: "Nuit au dortoir (Samedi)",
          fee_chf: 27,
          fee_eu: 27,
          quota: 40,
          position: 6,
          require_personal_infos: true
        },
        {
          name_en: "Night at the dormitory (Sunday)",
          name_fr: "Nuit au dortoir (Dimanche)",
          fee_chf: 27,
          fee_eu: 27,
          quota: 40,
          position: 7,
          require_personal_infos: true
        },
        {
          name_en: "2 Kyu examination",
          name_fr: "Examen de 2 Kyu",
          fee_chf: 20,
          fee_eu: 20,
          position: 8
        },
        {
          name_en: "1 Kyu examination",
          name_fr: "Examen de 1 Kyu",
          fee_chf: 30,
          fee_eu: 30,
          position: 9
        }
      ]

      individual_categories_data = [
        {
          name: "Junior U-12",
          pool_size: 3,
          out_of_pool: 2,
          min_age: nil,
          max_age: 12,
          description_en: "For juniors of both genders up to and including 12 years of age.
          12 year old Kendoka may compete in both the U-12 and U-15 categories".squish,
          description_fr: "Pour les juniors des deux sexes jusqu'à l'âge de 12 ans inclus.
          Les kendoka de 12 ans peuvent concourir dans les catégories U-12 et U-15".squish
        },
        {
          name: "Junior U-15",
          pool_size: 3,
          out_of_pool: 2,
          min_age: 12,
          max_age: 15,
          description_en: "For juniors of both genders between 12 and 15 years old.".squish,
          description_fr: "Pour les juniors des deux sexes âgés de 12 à 15 ans inclus.".squish
        },
        {
          name: "Open",
          pool_size: 3,
          out_of_pool: 2,
          min_age: 17,
          max_age: nil,
          description_en: "For competitors of both genders 16 years old or more.
          Participants less than 18 years old
          will be required to show a document signed by a legal representative".squish,
          description_fr: "Pour les compétiteurs des deux sexes âgés de 16 ans ou plus.
          Les participants nés en #{2024 - 16}
          et #{2024 - 17} devront présenter une décharge signée par un représentant légal".squish
        },
        {
          name: "Ladies",
          pool_size: 3,
          out_of_pool: 2,
          min_age: 17,
          max_age: nil,
          description_en: "For ladies who are 16 years or older.
          Participants less than 18 years old
          will be required to show a document signed by a legal representative".squish,
          description_fr: "Pour les femmes âgées de 16 ans et plus.
          Les participants nés en #{2024 - 16}
          et #{2024 - 17} devront présenter une décharge signée par un représentant légal".squish
        }
      ]

      team_categories_data = [
        {
          name: "Team",
          pool_size: nil,
          out_of_pool: nil,
          min_age: 17,
          max_age: nil,
          description_en: "A team consists of five fighters (at least three).
          The team order can be changed before each fight.
          The minimum age for participation in the team competition is 16 years.
          Participants less than 18 years old
          will be required to show a document signed by a legal representative".squish,
          description_fr: "Une équipe se compose de cinq combattants (au moins trois).
          L'ordre des équipes peut être modifié avant chaque combat.
          L'âge minimum pour participer à la compétition par équipe est de 16 ans.
          Les participants âgés de moins de 18 ans
          devront présenter un document signé par un représentant légal".squish
        }
      ]

      ActiveRecord::Base.transaction do
        cup = Cup.find_or_create_by(start_on: "2024-09-28", end_on: "2024-09-29", year: 2024)
        create_header_image(cup: cup, image: "kasa-2024.jpeg")
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
        product_team = cup.products.find_by!(name_en: "Participation Team")
        product_individual_junior = cup.products
          .find_by!(name_en: "Participation Individuals Junior (17 years old and younger)")
        product_individual_adult = cup.products
          .find_by!(name_en: "Participation Individuals Adult (18 years old and older)")
        product_full_junior = cup.products
          .find_by!(name_en: "Participation 2 Days Junior (17 years old and younger)")
        product_full_adult = cup
          .products.find_by!(name_en: "Participation 2 Days Adult (18 years old and older)")
        cup.update!(
          product_individual_junior: product_individual_junior,
          product_individual_adult: product_individual_adult,
          product_team: product_team,
          product_full_junior: product_full_junior,
          product_full_adult: product_full_adult,
          deadline: "2024-09-15",
          registerable_at: "2024-05-01 00:00:00",
          description_en: nil,
          description_fr: nil
        )
      end
    end
  end
end
