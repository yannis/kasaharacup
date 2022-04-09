# frozen_string_literal: true

require_relative "add_results"
namespace :temporary do
  namespace :cups do
    desc "Add results, documents and videos for 2016"
    task add_2016: :environment do
      include AddResults
      ActiveRecord::Base.transaction do
        cup = Cup.find_by!(year: 2016)
        add_team_results(
          cup: cup,
          team_names: ["Ken Shin Kan", "Swiss Men", "Saint-Etienne", "Budokan Mix"],
          videos: [
            {name: "Kasahara Kendo Cup 2016 – Team final", url: "https://youtu.be/CZSCboVKMtM"}
          ],
          documents: [
            {file_path: "2016/Teams_2016.pdf", name: "Tree"}
          ]
        )
        add_individual_results(
          cup: cup,
          category_name: "Open",
          kenshi_names: [
            ["Endy", "Thivolle"],
            ["Sylvain", "Chodkowski"],
            ["Yannick", "Rothacher"],
            ["Yannis", "Jaquet"],
            ["Marine", "Vandenberghe"]
          ],
          videos: [
            {name: "Kasahara Kendo Cup 2016 – Open Final", url: "https://youtu.be/T70EHfo9IKE"}
          ],
          documents: [
            {file_path: "2016/Open_pools_2016.pdf", name: "Pools"},
            {file_path: "2016/Open_A1_2016.pdf", name: "Tree A1"},
            {file_path: "2016/Open_A2_2016.pdf", name: "Tree A2"},
            {file_path: "2016/Open_B1_2016.pdf", name: "Tree B1"},
            {file_path: "2016/Open_B2_2016.pdf", name: "Tree B2"}
          ]
        )
        add_individual_results(
          cup: cup,
          category_name: "Ladies",
          kenshi_names: [
            ["Pauline", "Stolarz"],
            ["Laure", "Bellivier"],
            ["Kayoko", "Nagano"],
            ["Magda", "Badir"],
            ["Sara", "Van Laecken"]
          ],
          videos: [{name: "Kasahara Kendo Cup 2016 – Ladies final", url: "https://youtu.be/66hyX1BFULI"}],
          documents: [
            {file_path: "2016/Ladies_pools_2016.pdf", name: "Pools"},
            {file_path: "2016/Ladies_2016.pdf", name: "Tree"}
          ]
        )
        add_individual_results(
          cup: cup,
          category_name: "Junior1",
          kenshi_names: [
            ["Theo", "Renz"],
            ["Noam", "Viallet"],
            ["Jvar", "Koller"],
            ["Takumi", "Henry-Viel"],
            ["Kaori Kimberleigh", "Krammer"]
          ],
          documents: [
            {file_path: "2016/Juniors_1_pools_2016.pdf", name: "Pools"},
            {file_path: "2016/Juniors_1_2016.pdf", name: "Tree"}
          ]
        )
        add_individual_results(
          cup: cup,
          category_name: "Junior2",
          kenshi_names: [
            ["Quentin", "Dosch"],
            ["Naoki", "Henry-Viel"],
            ["Mathéo", "Chesneau"],
            ["Erik", "Koller"],
            ["Luca", "Dubret"]
          ],
          documents: [
            {file_path: "2016/Juniors_2_pools_2016.pdf", name: "Pools"},
            {file_path: "2016/Juniors_2_2016.pdf", name: "Tree"}
          ]
        )
      end
    end
  end
end
