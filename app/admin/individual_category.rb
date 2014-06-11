ActiveAdmin.register IndividualCategory do

  permit_params :name, :pool_size, :out_of_pool, :min_age, :max_age, :description_en, :description_fr, :cup_id

  index do
    column :name do |category|
      link_to category.name, admin_individual_category_path(category)
    end
    column :description
    column :pool_size
    column :out_of_pool
    column :reset_pools do |category|
      link_to( "Smart", reset_smart_pools_admin_individual_category_path(category), confirm: "Are you sure?")
      # " "+
      # link_to( "Dumb", reset_dumb_pools_admin_category_path(category), confirm: "Are you sure?")
    end
    actions
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
  end

  member_action :reset_smart_pools do
    @category = IndividualCategory.find params[:id]
    @category.set_smart_pools
    flash[:notice] = "Pool smartly reset"
    redirect_to action: 'show'
  end
end
