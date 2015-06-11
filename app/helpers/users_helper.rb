module UsersHelper

  def user_admin_links(user, nav: nil)
    links = []
    if user.attributes == current_user.attributes && !user.registered_for_cup?(@current_cup)
      links << link_to("<span class='glyphicon glyphicon-plus'></span> #{t("users.show.register_yourself")}".html_safe, new_cup_user_kenshi_path(@current_cup, current_user, self: true), class: "btn btn-xs btn-info")
    end
    if can?(:update, user)
      links << link_to("<span class='glyphicon glyphicon-edit'></span> edit".html_safe, edit_user_registration_path(user), class: "btn btn-xs btn-info")
    end
    if can?(:destroy, user)
      links << link_to("<span class='glyphicon glyphicon-trash'></span> #{t("devise.registrations.cancel_title")}".html_safe , registration_path(user), data: { confirm: t("devise.registrations.cancel_verif") }, method: :delete, class: "btn btn-xs btn-danger")
    end
    return content_tag(:div, class: "admin_links btn-group") do
      for link in links
        concat(link)
      end
    end
  end

end
