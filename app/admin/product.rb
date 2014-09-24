ActiveAdmin.register Product do
  permit_params :name_en, :name_fr, :description_en, :description_fr, :cup_id, :event_id, :fee_chf, :fee_eu

  index do
    column :name_en do |product|
      link_to product.name, [:admin, product]
    end
    column :cup
    column :event
    column :description_en
    column :fee_chf
    column :fee_eu
    actions
  end

  show do |product|
    attributes_table do
      row :name_en
      row :name_fr
      row :cup
      row :event
      row :description_en
      row :description_fr
      row :fee_chf
      row :fee_eu
    end

    if product.kenshis.present?
      panel "Kenshis" do
        table_for product.kenshis.order(:last_name, :first_name) do |kenshi|
          column :last_name
          column :first_name
          column :email
          column :club
          # column :categories do
          #   (kenshi.individual_categories.map{|c| link_to(c.name, [:admin, c])}+kenshi.teams.map{|t| "#{link_to(t.name, [:admin, t])} (#{link_to(t.team_category.name, [:admin, t.team_category])})"}).join(', ').html_safe
          # end
          # column :products do |kenshi|
          #   kenshi.products.map{|c| link_to(c.name, [:admin, c])}.join(', ').html_safe
          # end
          column :user do |kenshi|
            "#{kenshi.user.full_name} (#{kenshi.user.email})"
          end
          # actions do |kenshi|
          #   link_to "PDF", pdf_admin_kenshi_path(kenshi)
          # end
        end
      end
    end
  end

  member_action :download_kenshi_list, method: :get do
    @product = Product.find params[:id]
    kenshis = @product.kenshis
    csv = CSV.generate do |csv|
      header = ["Last name", "First name", "Club", "Dob", "Grade"]
      csv << header.flatten
      kenshis.each do |kenshi|
        kcsv = [ kenshi.norm_last_name, kenshi.norm_first_name, kenshi.club.name, kenshi.dob, kenshi.grade ]
        csv << kcsv.flatten
      end
    end

    send_data csv, type: 'text/csv; charset=utf-8; header=present', disposition: "attachment; filename=product_#{@product.name.parameterize}_kenshis_list_#{Time.current.to_s(:flat)}.csv"
  end

  action_item only: :show do
    link_to('Kenshis list', params.merge(action: :download_kenshi_list))
  end
end
