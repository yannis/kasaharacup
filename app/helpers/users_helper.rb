module UsersHelper

  def user_admin_links(user, nav: nil)
    links = []
    links << link_to("<span class='glyphicon glyphicon-plus'></span> #{t("users.show.register_yourself")}".html_safe, new_user_kenshi_path(current_user, self: true), class: "btn btn-xs btn-info") if user == current_user && !user.registered_for_cup?(@cup)
    links << link_to("<span class='glyphicon glyphicon-edit'></span> edit".html_safe, edit_user_registration_path(user), class: "btn btn-xs btn-info") if can?(:update, user)
    links << link_to("<span class='glyphicon glyphicon-trash'></span> #{t("devise.registrations.cancel_title")}".html_safe , registration_path(user), data: { confirm: t("devise.registrations.cancel_verif") }, method: :delete, class: "btn btn-xs btn-danger") if can?(:destroy, user)

    return content_tag(:div, class: "admin_links") do
      for link in links
        concat(link)
      end
    end
  end

end
