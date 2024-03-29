# frozen_string_literal: true

ActiveAdmin.register Participation, as: "Participation" do
  permit_params :category_id, :category_type, :team_id, :pool_number, :pool_position, :ronin, :category_individual,
    :category_team, :rank, :fighting_spirit

  controller do
    def scoped_collection
      super.includes(:team, :kenshi, category: :cup)
    end

    def edit
      participation = Participation.find(params[:id])
      @page_title = "Edit participation of #{participation.kenshi.full_name}" \
       " to category #{participation.category.name} (#{participation.category.year})"
    end
  end

  index do
    column :kenshi
    column :category
    column :team
    column :pool_number
    column :pool_position
    column :ronin
    column :rank
    column :fighting_spirit
    actions
  end

  show title: proc { |participation|
                "Participation of #{participation.kenshi.full_name} to category" \
                " #{participation.category.name} (#{participation.category.year})"
              } do
    attributes_table do
      row :kenshi
      row :category
      row :team
      row :pool_number
      row :pool_position
      row :ronin
      row :rank
      row :fighting_spirit
    end
  end

  form do |f|
    f.object.errors
    f.semantic_errors
    f.inputs "Participation details" do
      if f.object.category.is_a?(IndividualCategory)
        f.input :pool_number
        f.input :pool_position
        f.input :rank
        f.input :fighting_spirit
      elsif f.object.category.is_a?(TeamCategory)
        f.input :ronin
        f.input :team, collection: f.object.category.cup.teams.map { |c| ["#{c.name} (#{c.cup.year})", c.id] }
      end
    end

    f.actions
  end
end
