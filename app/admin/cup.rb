# frozen_string_literal: true

ActiveAdmin.register Cup do
  menu priority: 1

  permit_params :year, :start_on, :end_on, :deadline, :canceled_at, :registerable_at, :description_en, :description_fr,
    :header_image, :product_individual_junior_id, :product_individual_adult_id

  controller do
    def find_resource
      Cup.where(year: params[:id]).first!
    end
  end

  form do |f|
    f.semantic_errors # shows errors on :base
    f.inputs "Details" do
      f.input :start_on, as: :datepicker
      f.input :end_on, as: :datepicker
      f.input :deadline, as: :datepicker
      f.input :canceled_at, as: :datepicker
      f.input :registerable_at, as: :datepicker
      f.input(
        :product_individual_junior_id,
        as: :select,
        collection: f.object.products
          .order(:position)
          .where("LOWER(products.name_en) ~ 'junior'")
          .map { |p| [p.name, p.id] }
      )
      f.input(
        :product_individual_adult_id,
        as: :select,
        collection: f.object.products
          .order(:position)
          .where("LOWER(products.name_en) ~ 'adult'")
          .map { |p| [p.name, p.id] }
      )
      f.input :description_en
      f.input :description_fr
      f.input :header_image, as: :file
    end
    f.actions
  end

  index do
    column :year do |cup|
      link_to(cup.year, admin_cup_path(cup))
    end
    column :start_on
    column :end_on
    column :deadline
    column :canceled?
    column :product_individual_junior do |cup|
      cup.product_individual_junior&.name
    end
    column :product_individual_adult do |cup|
      cup.product_individual_adult&.name
    end
    column :description do |cup|
      md_to_html(cup.description)
    end
    column :header_image do |cup|
      next unless cup.header_image.attached?

      image = cup.header_image.variant(:thumb).processed ? cup.header_image.variant(:thumb) : cup.header_image
      image_tag(
        image,
        alt: "hero"
      )
    end
    actions
  end

  show title: proc { |cup| cup.year } do |cup|
    attributes_table do
      row :start_on
      row :end_on
      row :deadline
      row :canceled?
      row :registerable_at
      row :product_individual_junior do |cup|
        if cup.product_individual_junior
          link_to cup.product_individual_junior&.name,
            [:admin, cup.product_individual_junior]
        end
      end
      row :product_individual_adult do |cup|
        if cup.product_individual_adult
          link_to cup.product_individual_adult&.name,
            [:admin, cup.product_individual_adult]
        end
      end
      row :description_en
      row :description_fr
      row :header_image do |cup|
        next unless cup.header_image.attached?

        image = cup.header_image.variant(:thumb).processed ? cup.header_image.variant(:thumb) : cup.header_image
        image_tag(
          image,
          alt: "hero"
        )
      end
    end
    if cup.kenshis.present?
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
              cup.team_categories.each do |tc|
                th do
                  tc.name
                end
              end
              cup.individual_categories.each do |ic|
                th do
                  ic.name
                end
              end
              cup.products.each do |p|
                th do
                  p.name
                end
              end
            end
          end
          tbody do
            cup.kenshis.includes(participations: :category, purchases: :product).order(:last_name,
              :first_name).each do |kenshi|
              tr do
                td do
                  kenshi.norm_last_name
                end
                td do
                  kenshi.norm_first_name
                end
                cup.team_categories.each do |tc|
                  td do
                    tc.name if kenshi.takes_part_to? tc
                  end
                end
                cup.individual_categories.each do |ic|
                  td do
                    ic.name if kenshi.takes_part_to? ic
                  end
                end
                cup.products.each do |p|
                  td do
                    p.name if kenshi.consume? p
                  end
                end
              end
            end
          end
        end
      end
    end
  end

  filter :year

  member_action :download_kenshi_list, method: :get do
    @cup = Cup.all.detect { |c| c.year.to_i == params[:id].to_i }
    kenshis = @cup.kenshis
      .includes(:user, :club, participations: :category, purchases: :product).order(:last_name, :first_name)
    csv = CSV.generate do |csv|
      header = [
        "Last name", "First name", "Inscrit par (nom)", "Inscrit par (email)", "Club", "Dob",
        "Grade", "Création", "Dernière modification"
      ]
      [@cup.team_categories, @cup.individual_categories, @cup.products].flatten.each do |tc|
        header << tc.name
      end
      header << "Fees CHF"
      header << "Fees €"
      csv << header.flatten
      kenshis.each do |kenshi|
        user = kenshi.user
        kcsv = [
          kenshi.norm_last_name, kenshi.norm_first_name, user.full_name, user.email,
          kenshi.club.name, kenshi.dob, kenshi.grade
        ]
        kcsv << kenshi.created_at.to_fs(:db)
        kcsv << kenshi.updated_at.to_fs(:db)
        @cup.team_categories.each do |tc|
          kcsv << (kenshi.takes_part_to?(tc) ? kenshi.participations.to(tc).first.team : nil)
        end
        @cup.individual_categories.each do |ic|
          kcsv << (kenshi.takes_part_to?(ic) ? ic.name : nil)
        end
        @cup.products.each do |p|
          kcsv << (kenshi.consume?(p) ? p.name : nil)
        end
        kcsv << kenshi.fees(:chf)
        kcsv << kenshi.fees(:eu)
        csv << kcsv.flatten
      end
    end

    send_data csv, type: "text/csv; charset=utf-8; header=present",
      disposition: "attachment; filename=cup_#{@cup.year}_kenshis_list_#{Time.current.to_fs(:flat)}.csv"
  end

  action_item :kenshi_list, only: :show do
    link_to("Kenshis list", download_kenshi_list_admin_cup_path)
  end
end
