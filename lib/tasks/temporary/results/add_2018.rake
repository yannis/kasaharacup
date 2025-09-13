# frozen_string_literal: true

require_relative "add_results"
namespace :temporary do
  namespace :cups do
    desc "Add results, documents and videos for 2018"
    task add_2018: :environment do
      include AddResults

      ActiveRecord::Base.transaction do
        cup = Cup.find_by!(year: 2018)
        create_header_image(cup: cup, image: "kasa-2018.jpeg")
        add_team_results(
          cup: cup,
          team_names: ["Kodokan", "Saint Etienne", "Racailloux d'auralsace", "Ronins"],
          videos: [
            {name: "Kasahara Kendo Cup 2018 – Team final", url: "https://youtu.be/_cIxzOqQdu0"}
          ],
          documents: [
            {file_path: "2018/Teams_pools_2018.pdf", name: "pools"},
            {file_path: "2018/Teams_pools_fights_2018.pdf", name: "pool fights"},
            {file_path: "2018/Teams_2018.pdf", name: "Tree"}
          ]
        )
        add_individual_results(
          cup: cup,
          category_name: "Open",
          kenshi_names: [
            ["Yoonsu", "Kim"],
            ["Fabrizio", "Mandia"],
            ["Ghais", "Guelaia"],
            ["Toru", "Izumi"],
            ["Carlos Daniel", "Del Valle Prada"]
          ],
          videos: [
            {name: "Kasahara Kendo Cup 2018 – Open Semi-Final 1", url: "https://youtu.be/awog3LLh1Ic"},
            {name: "Kasahara Kendo Cup 2018 – Open Semi-Final 2", url: "https://youtu.be/dGVyqmYKKHE"},
            {name: "Kasahara Kendo Cup 2018 – Open Final", url: "https://youtu.be/TyWKh_b9je8"}
          ],
          documents: [
            {file_path: "2018/Open_pools_2018.pdf", name: "Pools"},
            {file_path: "2018/Open_A1_2018.pdf", name: "Tree A1"},
            {file_path: "2018/Open_A2_2018.pdf", name: "Tree A2"},
            {file_path: "2018/Open_B1_2018.pdf", name: "Tree B1"},
            {file_path: "2018/Open_B2_2018.pdf", name: "Tree B2"}
          ]
        )
        add_individual_results(
          cup: cup,
          category_name: "Ladies",
          kenshi_names: [
            ["Veronika", "Orasch"],
            ["Marine", "Vandenberghe"],
            ["Kayoko", "Nagano"],
            ["Melissa", "Keranović"],
            ["Gin Jing", "Ching"]
          ],
          videos: [{name: "Kasahara Kendo Cup 2018 – Ladies final", url: "https://youtu.be/eZIQoYTGSHg"}],
          documents: [
            {file_path: "2018/Ladies_pools_2018.pdf", name: "Pools"},
            {file_path: "2018/Ladies_2018.pdf", name: "Tree"}
          ]
        )
        add_individual_results(
          cup: cup,
          category_name: "Junior1",
          kenshi_names: [
            ["Youzo", "Moutarde"],
            ["Tetsuya", "Hata"],
            ["Hiroaki", "Hata"],
            ["Ayaka", "Yamada"],
            ["Miku", "Yagi"]
          ],
          documents: [
            {file_path: "2018/Juniors_1_pools_2018.pdf", name: "Pools"},
            {file_path: "2018/Juniors_1_2018.pdf", name: "Tree"}
          ]
        )
        add_individual_results(
          cup: cup,
          category_name: "Junior2",
          kenshi_names: [
            ["Takumi", "Henry-Viel"],
            ["Niels", "Barraclough"],
            ["Pénélope", "Jaquet"]
          ],
          documents: [
            {file_path: "2018/Juniors_2_pools_2018.pdf", name: "Pools"},
            {file_path: "2018/Juniors_2_2018.pdf", name: "Tree"}
          ]
        )
      end
    end
  end
end
