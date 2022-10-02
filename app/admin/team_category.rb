# frozen_string_literal: true

ActiveAdmin.register TeamCategory do
  permit_params :name, :pool_size, :out_of_pool, :min_age, :max_age, :description_en, :description_fr,
    :cup_id

  controller do
    def scoped_collection
      super.includes(:cup, :participations, :teams)
    end
  end

  index do
    column :name do |c|
      link_to "#{c.name} (#{c.year})", [:admin, c]
    end
    column :teams_count, sortable: false do |team_category|
      team_category.teams.size
    end
    column :created_at
    column :updated_at
    actions
  end

  filter :cup, as: :check_boxes, collection: proc { Cup.all }
  filter :name

  show do |category|
    attributes_table do
      row :name
      row :cup
      row :description_en
      row :description_fr
      row :pool_size
      row :out_of_pool
    end
    if category.teams.present?
      panel "Teams" do
        table do
          thead do
            tr do
              th do
                "Name"
              end
              th do
                "Kenshis"
              end
            end
          end
          tbody do
            category.teams.includes(:kenshis).order(:name).each do |team|
              tr do
                td do
                  link_to(team.name, admin_team_path(team))
                end
                td do
                  team.kenshis.map do |k|
                    link_to(k.full_name, admin_kenshi_path(k))
                  end.join(", ").html_safe
                end
              end
            end
          end
        end
      end
    end
  end

  member_action :pdf do
    @team_category = TeamCategory.find params[:id]
    pdf = TeamCategoryPdf.new(@team_category)
    send_data pdf.render, filename: @team_category.name.parameterize(separator: "_"),
      type: "application/pdf",
      disposition: "inline",
      page_size: "A4"
  end
  action_item :pdf, only: :show do
    link_to "PDF", pdf_admin_team_category_path(team_category)
  end

  action_item :video_new, only: :show do
    link_to "New Video", new_admin_team_category_video_path(team_category)
  end

  action_item :new_document, only: :show do
    link_to("New document", new_admin_team_category_document_path(team_category))
  end

  # collection_action :pdfs do
  #   @team_categories = TeamCategory.order(:name)
  #   pdf = TeamCategoryPdf.new(@team_categories)
  #   send_data pdf.render, filename: "team_categories",
  #                         type: "application/pdf",
  #                         disposition: "inline",
  #                         page_size: 'A4'
  # end
  # action_item only: :index do
  #   link_to("PDF", pdfs_admin_team_categories_path)
  # end

  member_action :team_match_sheet do
    @team_category = TeamCategory.find params[:id]
    pdf = TeamCategoryMatchSheetPdf.new(@team_category)
    send_data pdf.render, filename: "#{@team_category.name}_#{@team_category.cup.year}_match_sheet",
      type: "application/pdf",
      disposition: "inline",
      page_size: "A4"
  end
  action_item :match_sheet, only: :show do
    link_to "Match sheet", team_match_sheet_admin_team_category_path(team_category)
  end
end
