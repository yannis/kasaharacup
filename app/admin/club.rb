# frozen_string_literal: true

ActiveAdmin.register Club, as: "Club" do
  permit_params :name

  show do |club|
    attributes_table do
      row :name
      row :created_at
      row :updated_at
    end
    if club.kenshis.present?
      panel "Kenshis" do
        table do
          thead do
            tr do
              th do
                "Last name"
              end
              th do
                "First name"
              end
              th do
                "Cup"
              end
            end
          end
          tbody do
            club.kenshis.order(:last_name, :first_name).each do |kenshi|
              tr do
                td do
                  link_to kenshi.norm_last_name, admin_kenshi_path(kenshi)
                end
                td do
                  kenshi.norm_first_name
                end
                td do
                  kenshi.cup.year
                end
              end
            end
          end
        end
      end
    end
  end
end
