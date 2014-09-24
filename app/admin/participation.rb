ActiveAdmin.register Participation do

  permit_params :category_id, :category_type, :team_id, :pool_number, :pool_position, :ronin

  index do
    column :kenshi
    column :category
    column :team
    column :pool_number
    column :pool_position
    column :ronin
    actions
  end

  form do |f|
    f.object.errors
    f.semantic_errors *f.object.errors.keys
    f.inputs "Participation details" do
      f.input :kenshi
      f.input :category_type, collection: [IndividualCategory, TeamCategory]
      f.input :category, collection: IndividualCategory.all+TeamCategory.all
      f.input :team
      f.input :pool_number
      f.input :pool_position
      f.input :ronin

    end

    f.actions
  end
end
