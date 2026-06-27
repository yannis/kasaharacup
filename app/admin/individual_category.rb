# frozen_string_literal: true

ActiveAdmin.register IndividualCategory, as: "IndividualCategory" do
  permit_params :name, :pool_size, :out_of_pool, :min_age, :max_age, :gender_restriction,
    :description_en, :description_fr, :cup_id

  form do |f|
    f.semantic_errors
    f.inputs do
      f.input :cup
      f.input :name
      f.input :description_en
      f.input :description_fr
      f.input :pool_size
      f.input :out_of_pool
      f.input :min_age
      f.input :max_age
      f.input :gender_restriction,
        as: :select,
        collection: IndividualCategory.gender_restrictions.keys,
        include_blank: "Open"
    end
    f.actions
  end

  controller do
    def scoped_collection
      super.includes(:cup, :participations)
    end
  end

  filter :cup, as: :check_boxes, collection: proc { Cup.all }
  filter :name

  index do
    column :name do |c|
      link_to "#{c.name} (#{c.year})", [:admin, c]
    end
    column :description_en
    column :description_fr
    column :pool_size
    column :out_of_pool
    column :min_age
    column :max_age
    column :gender_restriction
    column :kenshi_count do |c|
      c.participations.size
    end
    actions do |category|
      [
        link_to("Smart reset", reset_smart_pools_admin_individual_category_path(category),
          data: {confirm: "Regenerate all pools for this category? Manual pool assignments will be lost."}),
        link_to("PDF", pdf_admin_individual_category_path(category)),
        link_to("PDF recap", pdf_recap_admin_individual_category_path(category)),
        link_to("Match sheet", sheet_admin_individual_category_path(category)),
        link_to("Pool match sheets", pool_sheets_admin_individual_category_path(category))
      ].join(" ").html_safe
    end
  end

  show do |category|
    attributes_table do
      row :cup
      row :name
      row :description_en
      row :description_fr
      row :pool_size
      row :out_of_pool
      row :gender_restriction
    end
    if category.pool_size.to_i > 1
      panel "Pools" do
        if category.pools.any? && category.pool_fights.empty?
          div do
            span link_to("Generate pool fights",
              generate_pool_fights_admin_individual_category_path(category),
              method: :post,
              data: {confirm: "Generate the cyclic match list for all pools?"})
          end
        end
        # Always rendered (even with zero pools) so the first new pool card can
        # land. The pool-membership controller re-renders this same partial to
        # add a new pool, so the container markup lives in one place.
        render partial: "admin/individual_categories/pools", locals: {category: category}
        # Late registrants (pool_number nil): drag onto a pool or use the
        # per-row "Add to…" select. Renders an empty container when there are
        # none, and lists every participant before any pool is generated.
        render IndividualPoolUnpooledComponent.new(category: category)
      end
    end

    panel "Competition tree" do
      div do
        if category.bracket_fights.none?
          span link_to("Generate tree", generate_bracket_admin_individual_category_path(category), method: :post,
            data: {confirm: "Generate the competition tree from current pool results?"})
        else
          span link_to("Update tree", generate_bracket_admin_individual_category_path(category),
            method: :post,
            data: {confirm: "Fill in the latest pool ranks. Recorded winners are kept."})
          span " | "
          span link_to("Force rebuild",
            generate_bracket_admin_individual_category_path(category, rebuild_started: true),
            method: :post,
            data: {confirm: "This destroys the existing tree and recorded winners, " \
              "and rebuilds from scratch. Continue?"})
          span " | "
          span link_to("Download PDF", competition_tree_pdf_admin_individual_category_path(category))
        end
      end
      render CompetitionTreeComponent.new(category: category, admin: true)
    end

    if category.pool_size.to_i <= 1 && category.participations.no_pool.present?
      panel "Participations without pool number" do
        table_for category.participations.no_pool do |participation|
          column :full_name do |participation|
            if participation.kenshi.present?
              link_to participation.full_name, admin_kenshi_path(participation.kenshi)
            else
              participation.full_name
            end
          end
          column :grade
          column :club
          column :age do |participation|
            participation.kenshi.age_at_cup
          end
          column :admin_links do |participation|
            [
              link_to("View", admin_participation_path(participation)),
              link_to("Edit", edit_admin_participation_path(participation)),
              link_to("Destroy",
                admin_participation_path(participation),
                method: :delete,
                data: {confirm: "Are you extra sure?"})
            ].join(" ").html_safe
          end
        end
      end
    end
    if category.videos.any?
      panel "Videos" do
        table_for category.videos do |video|
          column :name
          column :url do |video|
            link_to video.url, video.url
          end
        end
      end
    end
    if category.documents.any?
      panel "Documents" do
        table_for category.documents.with_attached_file do |document|
          column :name
          column :url do |document|
            link_to document.file.filename, document.file.url
          end
        end
      end
    end
  end

  member_action :reset_smart_pools do
    @category = IndividualCategory.find params[:id]
    @category.set_smart_pools
    flash[:notice] = "Pool smartly reset" # rubocop:disable Rails/I18nLocaleTexts
    redirect_to action: "show"
  end
  action_item :smart_pool_reset, only: :show do
    link_to "Smart pool reset", reset_smart_pools_admin_individual_category_path(individual_category),
      data: {confirm: "Regenerate all pools for this category? Manual pool assignments will be lost."}
  end

  member_action :pdf do
    @category = IndividualCategory.find params[:id]
    pdf = IndividualCategoryPdf.new(@category)
    send_data pdf.render, filename: @category.name.parameterize(separator: "_"),
      type: "application/pdf",
      disposition: "inline",
      page_size: "A4"
  end
  action_item :pdf, only: :show do
    link_to "PDF", pdf_admin_individual_category_path(individual_category)
  end

  member_action :pdf_recap do
    @category = IndividualCategory.find params[:id]
    pdf = IndividualCategoryPdfRecap.new(@category)
    send_data pdf.render, filename: @category.name.parameterize(separator: "_"),
      type: "application/pdf",
      disposition: "inline",
      page_size: "A4"
  end
  action_item :pdf_recap, only: :show do
    link_to "PDF Recap", pdf_recap_admin_individual_category_path(individual_category)
  end

  member_action :pool_sheets do
    @category = IndividualCategory.find params[:id]
    pdf = IndividualCategoryPoolMatchesPdf.new(@category)
    send_data pdf.render, filename: @category.name.parameterize(separator: "_"),
      type: "application/pdf",
      disposition: "inline",
      page_size: "A4"
  end

  member_action :sheet do
    @category = IndividualCategory.find params[:id]
    pdf = IndividualCategoryMatchSheetPdf.new(@category)
    send_data pdf.render, filename: @category.name.parameterize(separator: "_"),
      type: "application/pdf",
      disposition: "inline",
      page_size: "A4"
  end

  member_action :competition_tree_pdf do
    @category = IndividualCategory.find params[:id]
    pdf = CompetitionTreePdf.new(@category)
    send_data pdf.render,
      filename: "#{@category.name.parameterize(separator: "_")}_competition_tree.pdf",
      type: "application/pdf",
      disposition: "inline"
  end

  action_item :new_video, only: :show do
    link_to("New video", new_admin_individual_category_video_path(individual_category))
  end

  action_item :new_document, only: :show do
    link_to("New document", new_admin_individual_category_document_path(individual_category))
  end

  action_item :match_sheet, only: :show do
    [link_to("Pool match sheet", pool_sheets_admin_individual_category_path(individual_category)),
      link_to("Match sheets", sheet_admin_individual_category_path(individual_category))].join(" ").html_safe
  end

  member_action :download_kenshi_list, method: :get do
    @individual_category = IndividualCategory.find params[:id]
    kenshis = @individual_category.kenshis
    csv = CSV.generate do |csv|
      header = ["Last name", "First name", "Club", "Dob", "Grade"]
      csv << header.flatten
      kenshis.each do |kenshi|
        kcsv = [kenshi.norm_last_name, kenshi.norm_first_name, kenshi.club.name, kenshi.dob, kenshi.grade]
        csv << kcsv.flatten
      end
    end

    filename = [
      "individual_category",
      @individual_category.name.parameterize,
      "kenshis_list",
      Time.current.to_fs(:flat),
      "csv"
    ].join("_")

    send_data(csv,
      type: "text/csv; charset=utf-8; header=present",
      disposition: "attachment; filename=#{filename}")
  end

  action_item :kenshi_list, only: :show do
    link_to("Kenshis list", params.permit!.merge(action: :download_kenshi_list))
  end
end
