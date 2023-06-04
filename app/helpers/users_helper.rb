# frozen_string_literal: true

module UsersHelper
  def user_admin_links(user, nav: nil)
    links = []
    if user.attributes == current_user.attributes &&
        !user.registered_for_cup?(@current_cup) &&
        can?(:register, @current_cup)
      links << link_to(t("users.show.register_yourself"),
        new_cup_user_kenshi_path(@current_cup, self: true), class: "btn btn-sm btn-secondary ml-2")
    end

    if can?(:update, user)
      links << link_to(
        t("users.show.edit"),
        edit_user_registration_path,
        class: "btn btn-sm btn-secondary ml-2"
      )
    end

    if can?(:destroy, user)
      links << link_to(
        t("devise.registrations.cancel_title"),
        user_registration_path,
        data: {turbo_method: :delete, turbo_confirm: t("devise.registrations.cancel_verif")},
        class: "btn btn-sm btn-secondary ml-2"
      )
    end

    content_tag(:div, class: "admin_links btn-group") do
      links.each do |link|
        concat(link)
      end
    end
  end
end
