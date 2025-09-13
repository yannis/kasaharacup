# frozen_string_literal: true

require_relative "add_results"
namespace :temporary do
  namespace :cups do
    desc "Add results, documents and videos for 2017"
    task add_2017: :environment do
      include AddResults

      ActiveRecord::Base.transaction do
        cup = Cup.find_by!(year: 2017)
        create_header_image(cup: cup, image: "kasa-2017.jpeg")
        add_team_results(
          cup: cup,
          team_names: ["Kodokan Alessandria", "KJB", "Saint Etienne", "Versailles Budo"],
          videos: [
            {name: "Kasahara Kendo Cup 2017 – Team final", url: "https://youtu.be/YPMrYadKMKk"}
          ],
          documents: [
            {file_path: "2017/Teams_2017.pdf", name: "Tree"}
          ]
        )
        add_individual_results(
          cup: cup,
          category_name: "Open",
          kenshi_names: [
            ["Hervé", "Blanchard"],
            ["Endy", "Thivolle"],
            ["Andres", "Massa"],
            ["Romain", "Longuepe"],
            ["Genta", "Kozaki"]
          ],
          videos: [
            {name: "Kasahara Kendo Cup 2017 – Open Final", url: "https://youtu.be/OXNRRem0FaI"}
          ],
          documents: [
            {file_path: "2017/Open_pools_2017.pdf", name: "Pools"},
            {file_path: "2017/Open_A1_2017.pdf", name: "Tree A1"},
            {file_path: "2017/Open_A2_2017.pdf", name: "Tree A2"},
            {file_path: "2017/Open_B1_2017.pdf", name: "Tree B1"},
            {file_path: "2017/Open_B2_2017.pdf", name: "Tree B2"}
          ]
        )
        add_individual_results(
          cup: cup,
          category_name: "Ladies",
          kenshi_names: [
            ["Sabrina", "Kumpf"],
            ["Kiyoko", "Moutarde"],
            ["Laura", "Schäfer"],
            ["Aurélia", "Blanchard"],
            ["María", "Slöcker"]
          ],
          videos: [{name: "Kasahara Kendo Cup 2017 – Ladies final", url: "https://youtu.be/UUvApRHDNgw"}],
          documents: [
            {file_path: "2017/Ladies_pools_2017.pdf", name: "Pools"},
            {file_path: "2017/Ladies_2017.pdf", name: "Tree"}
          ]
        )
        add_individual_results(
          cup: cup,
          category_name: "Junior1",
          kenshi_names: [
            ["Tadeu", "Kimura"],
            ["Kilian", "Hecht"],
            ["Youzo", "Moutarde"],
            ["Naima", "Geiger"],
            ["Kaori Kimberleigh", "Krammer"]
          ],
          videos: [{name: "Kasahara Kendo Cup 2017 – Junior 1", url: "https://youtu.be/wGBA8auLJY8"}],
          documents: [
            {file_path: "2017/Juniors_1_pools_2017.pdf", name: "Pools"},
            {file_path: "2017/Juniors_1_2017.pdf", name: "Tree"}
          ]
        )
        add_individual_results(
          cup: cup,
          category_name: "Junior2",
          kenshi_names: [
            ["Ugo", "Goliard"],
            ["Naoki", "Henry-Viel"],
            ["Theo", "Renz"],
            ["Erik", "Koller"],
            ["Thais", "Kimura"]
          ],
          videos: [{name: "Kasahara Kendo Cup 2017 – Junior 2", url: "https://youtu.be/PDB9DQQXhu0"}],
          documents: [
            {file_path: "2017/Juniors_2_pools_2017.pdf", name: "Pools"},
            {file_path: "2017/Juniors_2_2017.pdf", name: "Tree"}
          ]
        )
      end
    end
  end
end
