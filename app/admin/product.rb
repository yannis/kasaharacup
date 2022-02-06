# frozen_string_literal: true

ActiveAdmin.register Product, as: "Product" do
  permit_params :name_en, :name_fr, :description_en, :description_fr, :cup_id, :event_id,
    :fee_chf, :fee_eu

  controller do
    def authenticate_admin_user!
      redirect_to root_url unless current_user.try(:admin?)
    end
  end

  index do
    column :name_en do |product|
      link_to product.name_en, [:admin, product] if product.name_en
    end
    column :name_fr do |product|
      link_to product.name_fr, [:admin, product] if product.name_fr
    end
    column :cup
    column :event
    column :description_en
    column :description_fr
    column :fee_chf
    column :fee_eu
    actions
  end

  filter :cup, as: :check_boxes, collection: proc { Cup.all }
  filter :name

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
          column :user do |kenshi|
            "#{kenshi.user.full_name} (#{kenshi.user.email})"
          end
        end
      end
    end
  end

  form do |f|
    f.inputs "Details" do
      f.input :cup
      f.input :event, collection: Event.all.map { |e| ["#{e.name} (#{e.cup})", e.id] }
      f.input :name_en
      f.input :name_fr
      f.input :description_en
      f.input :description_fr
      f.input :fee_chf
      f.input :fee_eu
    end
    f.actions
  end

  member_action :download_kenshi_list, method: :get do
    @product = Product.find params[:id]
    kenshis = @product.kenshis
    csv = CSV.generate do |csv|
      header = ["Last name", "First name", "Club", "Dob", "Grade"]
      csv << header.flatten
      kenshis.each do |kenshi|
        kcsv = [kenshi.norm_last_name, kenshi.norm_first_name, kenshi.club.name, kenshi.dob, kenshi.grade]
        csv << kcsv.flatten
      end
    end

    disp = "attachment; filename=product_#{@product.name.parameterize}_kenshis_list_#{Time.current.to_s(:flat)}.csv"
    send_data(
      csv,
      type: "text/csv; charset=utf-8; header=present",
      disposition: disp
    )
  end

  action_item :kenshi_list, only: :show do
    link_to("Kenshis list", params.merge(action: :download_kenshi_list))
  end
end
