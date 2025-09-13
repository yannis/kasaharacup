# frozen_string_literal: true

require_relative "add_results"
namespace :temporary do
  namespace :cups do
    desc "Add results, documents and videos for 2019"
    task add_2019: :environment do
      include AddResults

      ActiveRecord::Base.transaction do
        cup = Cup.find_by!(year: 2019)
        create_header_image(cup: cup, image: "kasa-2019.jpeg")
        add_team_results(
          cup: cup,
          team_names: ["Saint-Etienne", "Kodokan Alessandria", "Buchelay", "Swiss Men"],
          videos: [
            {name: "Kasahara Kendo Cup 2019 – Team final", url: "https://youtu.be/vebQwUa7Ejs"}
          ],
          documents: [
            {file_path: "2019/Teams_2019.pdf", name: "Tree"}
          ]
        )
        add_individual_results(
          cup: cup,
          category_name: "Open",
          kenshi_names: [
            ["Daisuke", "Endo"],
            ["Yannis", "Jaquet"],
            ["Arnaud", "Pons"],
            ["Giliam", "Sayad"],
            ["Carlos", "Del Valle"]
          ],
          videos: [
            {name: "Kasahara Kendo Cup 2019 – Open Final", url: "https://youtu.be/BPLQYIDapXU"}
          ],
          documents: [
            {file_path: "2019/Open_pools_2019.pdf", name: "Pools"},
            {file_path: "2019/Open_A1_2019.pdf", name: "Tree A1"},
            {file_path: "2019/Open_A2_2019.pdf", name: "Tree A2"},
            {file_path: "2019/Open_B1_2019.pdf", name: "Tree B1"},
            {file_path: "2019/Open_B2_2019.pdf", name: "Tree B2"}
          ]
        )
        add_individual_results(
          cup: cup,
          category_name: "Ladies",
          kenshi_names: [
            ["Sabrina", "Kumpf"],
            ["Lyna", "Maaziz"],
            ["Laure", "Bellivier"],
            ["Veronika", "Orasch"],
            ["Marine", "Vandenberghe"]
          ],
          videos: [{name: "Kasahara Kendo Cup 2019 – Ladies final", url: "https://youtu.be/W-WYHOTxNHM"}],
          documents: [
            {file_path: "2019/Ladies_pools_2019.pdf", name: "Pools"},
            {file_path: "2019/Ladies_1_2019.pdf", name: "Tree 1"},
            {file_path: "2019/Ladies_2_2019.pdf", name: "Tree 2"}
          ]
        )
        add_individual_results(
          cup: cup,
          category_name: "Junior U12",
          kenshi_names: [
            ["Masaki", "Yamanaka"],
            ["Youzo", "Moutarde"],
            ["David", "Jacquemoud"],
            ["Marco", "Hecht"],
            ["Hiroaki", "Hata"]
          ],
          documents: [
            {file_path: "2019/Juniors_U12_pools_2019.pdf", name: "Pools"},
            {file_path: "2019/Juniors_U12_2019.pdf", name: "Tree"}
          ]
        )
        add_individual_results(
          cup: cup,
          category_name: "Junior U15",
          kenshi_names: [
            ["Nolan", "Champagne"],
            ["Ewan", "Pialat"],
            ["Tetsuya", "Hata"],
            ["Pénélope", "Jaquet"],
            ["Marie", "Debonnaire"]
          ],
          videos: [{name: "Kasahara Kendo Cup 2019 – Junior U15 final", url: "https://youtu.be/XoGrvWHpiQU"}],
          documents: [
            {file_path: "2019/Juniors_U15_pools_2019.pdf", name: "Pools"},
            {file_path: "2019/Juniors_U15_2019.pdf", name: "Tree"}
          ]
        )
        add_individual_results(
          cup: cup,
          category_name: "Junior U18",
          kenshi_names: [
            ["Hiroki", "Yamanaka"],
            ["Mateo", "Chesneau"],
            ["Ugo", "Goliard"],
            ["Antonin", "Grebel"],
            ["Quentin", "Dosch"]
          ],
          documents: [
            {file_path: "2019/Juniors_U18_pools_2019.pdf", name: "Pools"},
            {file_path: "2019/Juniors_U18_2019.pdf", name: "Tree"}
          ]
        )
      end
    end
  end
end
