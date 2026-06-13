# frozen_string_literal: true

ActiveAdmin.register TeamCategory do
  permit_params :name, :pool_size, :out_of_pool, :min_age, :max_age, :gender_restriction,
    :description_en, :description_fr, :cup_id

  form do |f|
    f.semantic_errors
    f.inputs do
      f.input :cup
      f.input :name
      f.input :description_en
      f.input :description_fr
      f.input :pool_size, hint: "Blank or 1 = bracket-only (teams go straight to the elimination bracket)."
      f.input :out_of_pool, hint: "Qualifiers per pool; ignored for bracket-only categories."
      f.input :min_age
      f.input :max_age
      f.input :gender_restriction,
        as: :select,
        collection: TeamCategory.gender_restrictions.keys,
        include_blank: "Open"
    end
    f.actions
  end

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
      row :gender_restriction
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
    category_team_pools = category.team_pools
    if category.pool_size.to_i > 1 && category_team_pools.any?
      panel "Pools" do
        category_team_pools.each do |pool|
          div do
            render TeamPoolComponent.new(team_category: category, pool_number: pool.number, admin: true)
          end
        end
      end
    end
    if category.bracket_encounters.any?
      panel "Bracket" do
        div do
          unless category.bracket_only?
            span(link_to("Update bracket", generate_bracket_admin_team_category_path(category), method: :post))
            span " | "
          end
          rebuild_confirm = if category.bracket_only?
            "Redraw the bracket? Scores are lost."
          else
            "Rebuild the bracket from current standings? Scores on rebuilt encounters are lost."
          end
          span(link_to("Force rebuild", generate_bracket_admin_team_category_path(category, rebuild: 1),
            method: :post, data: {confirm: rebuild_confirm}))
        end
        render EncounterTreeComponent.new(team_category: category, admin: true)
        # Encounter editors load here (tree cards target this frame); kept as a
        # sibling of the tree frame so tree broadcasts can't wipe an open editor.
        text_node helpers.turbo_frame_tag(
          helpers.dom_id(category, :encounter_panel), autoscroll: true
        )
      end
    end
  end

  member_action :generate_pools, method: :post do
    category = TeamCategory.find(params[:id])
    if category.bracket_only?
      return redirect_to admin_team_category_path(category), alert: "Bracket-only category — no pool phase." # rubocop:disable Rails/I18nLocaleTexts
    end

    category.set_team_pools
    redirect_to admin_team_category_path(category), notice: "Pools generated." # rubocop:disable Rails/I18nLocaleTexts
  end

  member_action :generate_pool_encounters, method: :post do
    category = TeamCategory.find(params[:id])
    if category.bracket_only?
      return redirect_to admin_team_category_path(category), alert: "Bracket-only category — no pool phase." # rubocop:disable Rails/I18nLocaleTexts
    end

    PoolEncounterGenerator.new(category).call
    redirect_to admin_team_category_path(category), notice: "Pool encounters generated." # rubocop:disable Rails/I18nLocaleTexts
  end

  member_action :generate_bracket, method: :post do
    category = TeamCategory.find(params[:id])
    TeamCategoryBracketBuilder.new(category, rebuild_started: params[:rebuild].present?).call
    redirect_to admin_team_category_path(category), notice: "Bracket generated." # rubocop:disable Rails/I18nLocaleTexts
  end

  action_item :generate_pools, only: :show, if: proc { !resource.bracket_only? } do
    link_to "Generate pools", generate_pools_admin_team_category_path(team_category),
      method: :post, data: {confirm: "Redraw all pools? Manual pool assignments are lost."}
  end

  action_item :generate_pool_encounters, only: :show, if: proc { !resource.bracket_only? } do
    link_to "Generate pool encounters", generate_pool_encounters_admin_team_category_path(team_category),
      method: :post
  end

  action_item :generate_bracket, only: :show do
    link_to "Generate bracket", generate_bracket_admin_team_category_path(team_category),
      method: :post
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

  action_item :encounters, only: :show do
    link_to "Encounters", admin_team_category_encounters_path(team_category)
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
