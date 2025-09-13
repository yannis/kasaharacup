# frozen_string_literal: true

require_relative "add_results"
namespace :temporary do
  namespace :cups do
    desc "Add results, documents and videos for 2015"
    task add_2015: :environment do
      include AddResults

      ActiveRecord::Base.transaction do
        cup = Cup.find_by!(year: 2015)
        create_header_image(cup: cup, image: "kasa-2015.jpeg")
        add_team_results(
          cup: cup,
          team_names: ["Saint Etienne 1", "BUDO XI", "Alessandria", "Swiss Men"],
          videos: [
            {name: "Kasahara Kendo Cup 2015 – Team Semi-final 1", url: "https://youtu.be/yyGTc6tbH4U"},
            {name: "Kasahara Kendo Cup 2015 – Team Semi-final 2", url: "https://youtu.be/nqOqIJ-DWfg"},
            {name: "Kasahara Kendo Cup 2015 – Team final", url: "https://youtu.be/OLikP_9PyOY"}
          ],
          documents: [
            {file_path: "2015/Teams_2015.pdf", name: "Tree"}
          ]
        )
        add_individual_results(
          cup: cup,
          category_name: "Open",
          kenshi_names: [
            ["Fabrizio", "Mandia"],
            ["Arnaud", "Pons"],
            ["Sylvain", "Chodkowski"],
            ["Kei", "Ito"],
            ["Marine", "Vandenberghe"]
          ],
          videos: [
            {name: "Kasahara Kendo Cup 2015 – Open Semi-final 1", url: "https://youtu.be/To-VIsTAH1Y"},
            {name: "Kasahara Kendo Cup 2015 – Open Semi-final 2", url: "https://youtu.be/fDSm-g_iJdk"},
            {name: "Kasahara Kendo Cup 2015 – Open Final", url: "https://youtu.be/81vAB5NHDUg"}
          ],
          documents: [
            {file_path: "2015/open_pools_2015.pdf", name: "Pools"},
            {file_path: "2015/Open_A1_2015.pdf", name: "Tree A1"},
            {file_path: "2015/Open_A2_2015.pdf", name: "Tree A2"},
            {file_path: "2015/Open_B1_2015.pdf", name: "Tree B1"},
            {file_path: "2015/Open_B2_2015.pdf", name: "Tree B2"}
          ]
        )
        add_individual_results(
          cup: cup,
          category_name: "Ladies",
          kenshi_names: [
            ["Pauline", "Stolarz"],
            ["Kiyoko", "Moutarde"],
            ["Misato", "Chiba"],
            ["Inès", "Loidi"],
            ["Aneline", "Lamour"]
          ],
          videos: [{name: "Kasahara Kendo Cup 2015 – Ladies final", url: "https://youtu.be/bZgszx0HolU"}],
          documents: [
            {file_path: "2015/ladies_pools_2015.pdf", name: "Pools"},
            {file_path: "2015/Ladies_2015.pdf", name: "Tree"}
          ]
        )
        add_individual_results(
          cup: cup,
          category_name: "Junior1",
          kenshi_names: [
            ["Goliard", "Ugo"],
            ["Naoki", "Henry-Viel"],
            ["Theo", "Renz"],
            ["Takumi", "Henry-Viel"],
            ["Naima", "Geiger"]
          ],
          documents: [
            {file_path: "2015/Juniors1_pools_2015.pdf", name: "Pools"},
            {file_path: "2015/Juniors_1_2015.pdf", name: "Tree"}
          ]
        )
        add_individual_results(
          cup: cup,
          category_name: "Junior2",
          kenshi_names: [
            ["Masahiro", "Ueda"],
            ["Louis", "Moutard"],
            ["Enzo", "Thivolle"],
            ["Luca", "Dubret"],
            ["Brian", "Lupton"]
          ],
          videos: [{name: "Kasahara Kendo Cup 2015 – Junior2 final", url: "https://youtu.be/_cJXMFKPvWs"}],
          documents: [
            {file_path: "2015/Juniors2_pools_2015.pdf", name: "Pools"},
            {file_path: "2015/Juniors_2_2015.pdf", name: "Tree"}
          ]
        )
      end
    end
  end
end
