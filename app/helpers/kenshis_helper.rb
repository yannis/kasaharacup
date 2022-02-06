# frozen_string_literal: true

module KenshisHelper
  def kenshi_admin_links(kenshi, options: {})
    links = []

    if can?(:update, kenshi)
      links << link_to(t("kenshis.helpers.edit.text"), edit_cup_kenshi_path(@current_cup, kenshi),
        class: "btn btn-sm btn-secondary ml-2")
    end

    if can?(:destroy, kenshi)
      links << link_to(
        t("kenshis.helpers.destroy.text"),
        cup_kenshi_path(@current_cup, kenshi, locale: I18n.locale),
        data: {turbo_method: :delete, turbo_confirm: t("kenshis.helpers.destroy.confirm")},
        class: "btn btn-sm btn-secondary ml-2"
      )
    end

    if can?(:create, Kenshi) && current_user_admin_or_owner?(kenshi)
      links << link_to(t("kenshis.helpers.duplicate.text"),
        duplicate_cup_user_kenshi_path(@current_cup, kenshi), class: "btn btn-sm btn-secondary ml-2")
    end

    classes = options.fetch(:class, "")

    tag.div(class: "admin_links #{classes} btn-group", id: "#{kenshi.class.to_s.tableize}_#{kenshi.id}_admin_links") do
      links.each do |link|
        concat(link)
      end
    end
  end
end
