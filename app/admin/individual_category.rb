ActiveAdmin.register IndividualCategory do

  permit_params :name, :pool_size, :out_of_pool, :min_age, :max_age, :description_en, :description_fr, :cup_id

  index do
    column :name do |category|
      link_to category.name, admin_individual_category_path(category)
    end
    column :description
    column :pool_size
    column :out_of_pool
    column :min_age
    column :max_age
    column :kenshi_count do |c|
      c.participations.count
    end
    actions do |category|
      [
        link_to( "Smart reset", reset_smart_pools_admin_individual_category_path(category), confirm: "Are you sure?"),
        link_to( "PDF", pdf_admin_individual_category_path(category)),
        link_to("PDF recap", pdf_recap_admin_individual_category_path(category)),
        link_to("Match sheet", sheet_admin_individual_category_path(category)),
        link_to("Pool match sheets", pool_sheets_admin_individual_category_path(category))
      ].join(" ").html_safe
    end
  end

  show do |category|
    attributes_table do
      row :name
      row :description
      row :pool_size
      row :out_of_pool
    end
    if category.pools.present?
      panel "Pools" do
        for pool in category.pools.sort_by(&:number)
          h2 do
            "Pool #{pool.number}"
          end
          begin
            table_for pool.participations do |participation|
              column :full_name do |participation|
                link_to participation.full_name, admin_kenshi_path(participation.kenshi) if participation.kenshi
              end
              column :grade
              column :club
              column :admin_links do  |participation|
                link_to "Move to another pool", edit_admin_participation_path(participation)
              end
            end
          rescue
            "Pool invalid"
          end
        end
      end

      panel "Tree" do
        render partial: "category_tree", locals: {category: category}
      end
    end

    if category.participations.no_pool.present?
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
          column :admin_links do |participation|
            link_to "Move to another pool", edit_admin_participation_path(participation)
          end
        end
      end
    end
  end

  member_action :reset_smart_pools do
    @category = IndividualCategory.find params[:id]
    @category.set_smart_pools
    flash[:notice] = "Pool smartly reset"
    redirect_to action: 'show'
  end
  action_item only: :show do
    link_to "Smart pool reset", reset_smart_pools_admin_individual_category_path(individual_category), confirm: "Are you sure?"
  end


  member_action :pdf do
    @category = IndividualCategory.find params[:id]
    pdf = IndividualCategoryPdf.new(@category)
    send_data pdf.render, filename: @category.name.parameterize('_'),
                          type: "application/pdf",
                          disposition: "inline",
                          page_size: 'A4'

  end
  action_item only: :show do
    link_to "PDF", pdf_admin_individual_category_path(individual_category)
  end


  member_action :pdf_recap do
    @category = IndividualCategory.find params[:id]
    pdf = IndividualCategoryPdfRecap.new(@category)
    send_data pdf.render, filename: @category.name.parameterize('_'),
                          type: "application/pdf",
                          disposition: "inline",
                          page_size: 'A4'
  end
  action_item only: :show do
    link_to "PDF Recap", pdf_recap_admin_individual_category_path(individual_category)
  end

  member_action :pool_sheets do
    @category = IndividualCategory.find params[:id]
    pdf = IndividualCategoryPoolMatchesPdf.new(@category)
    send_data pdf.render, filename: @category.name.parameterize('_'),
                          type: "application/pdf",
                          disposition: "inline",
                          page_size: 'A4'
  end
  action_item only: :show do
    link_to("Match sheet", pool_sheets_admin_individual_category_path(individual_category))
  end

  member_action :sheet do
    @category = IndividualCategory.find params[:id]
    pdf = IndividualCategoryMatchSheetPdf.new(@category)
    send_data pdf.render, filename: @category.name.parameterize('_'),
                          type: "application/pdf",
                          disposition: "inline",
                          page_size: 'A4'
  end
  action_item only: :show do
    link_to "Pool match sheets", sheet_admin_individual_category_path(individual_category)
  end
end
