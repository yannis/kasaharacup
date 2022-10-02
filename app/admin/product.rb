# frozen_string_literal: true

ActiveAdmin.register Product, as: "Product" do
  permit_params :name_en, :name_fr, :description_en, :description_fr, :cup_id, :event_id,
    :fee_chf, :fee_eu, :quota

  controller do


    def scoped_collection
      super.includes(:cup, :event, :purchases)
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
    column :total do |product|
      product.purchases.size
    end
    column :quota
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
      row :quota
    end

    if product.kenshis.present?
      panel "Kenshis (#{product.kenshis.size})" do
        table_for product.kenshis.order(:created_at).each_with_index do |kenshi_with_index|
          column "#" do |kenshi_with_index|
            kenshi_with_index.last + 1
          end
          column :last_name do |kenshi_with_index|
            link_to(kenshi_with_index.first.last_name, [:admin, kenshi_with_index.first])
          end
          column :first_name do |kenshi_with_index|
            link_to(kenshi_with_index.first.first_name, [:admin, kenshi_with_index.first])
          end
          column :created_at do |kenshi_with_index|
            l(kenshi_with_index.first.created_at, format: :short)
          end
          column :user_name do |kenshi_with_index|
            kenshi_with_index.first.user.full_name
          end
          column :user_email do |kenshi_with_index|
            kenshi_with_index.first.user.email
          end
          column :remarks do |kenshi_with_index|
            kenshi_with_index.first.remarks
          end
        end
      end
    end
  end

  form do |f|
    f.inputs "Details" do
      f.input :cup
      f.input :event, collection: Event.joins(:cup).where(cup: f.object.cup).all.map { |e|
                                    ["#{e.name} (#{e.cup})", e.id]
                                  }
      f.input :name_en
      f.input :name_fr
      f.input :description_en
      f.input :description_fr
      f.input :fee_chf
      f.input :fee_eu
      f.input :quota, as: :number
    end
    f.actions
  end

  member_action :download_kenshi_list, method: :get do
    @product = Product.find params[:id]
    kenshis = @product.kenshis.order(:created_at)
    csv = CSV.generate do |csv|
      header = [
        "Last name",
        "First name",
        "Gender",
        "Registered at",
        "Club",
        "Dob",
        "Grade",
        "Registered by",
        "Remarks"
      ]
      csv << header.flatten
      kenshis.each do |kenshi|
        kcsv = [
          kenshi.norm_last_name,
          kenshi.norm_first_name,
          kenshi.female? ? "F" : "M",
          kenshi.created_at,
          kenshi.club.name,
          kenshi.dob,
          kenshi.grade,
          kenshi.user.full_name,
          kenshi.user.email,
          kenshi.remarks
        ]
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
    link_to("Kenshis list", request.params.merge(action: :download_kenshi_list))
  end
end
