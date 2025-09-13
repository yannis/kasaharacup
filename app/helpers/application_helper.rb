# frozen_string_literal: true

module ApplicationHelper
  def mandatory_fields
    "<p class='mandatory_fields'><span class='red_star'>*</span> #{t("layout.form.mandatory")}</p>".html_safe
  end

  def title(content, options = {page_title: true, meta_title: true})
    content_for(:title) { content } if options[:page_title]
    content_for(:header_title) { content_tag(:header, content_tag(:h1, content)) } if options[:meta_title]
  end

  def cup_description(cup)
    if @current_cup.end_on
      t(
        "layout.description",
        start_on: l(@current_cup.start_on, format: :day_only),
        end_on: l(@current_cup.end_on, format: :day_month_year)
      )
    else
      t("layout.description_short")
    end
  end

  def submit_or_cancel_form(f, text = nil)
    link = [f.submit(text, class: "btn btn-success")]
    link << t("form.or")
    link << link_to(t("form.cancel"), session[:return_to].nil? ? root_path : session[:return_to], accesskey: "ESC",
      title: "Cancel #{f.object_name} form",
      class: "cancel #{"close_div" if request.format == "application/javascript"}")
    link.join(" ").html_safe
  end

  def destroy_link(object, options = {})
    arr = object
    if object.is_a?(Array)
      object = object.last
    end
    text = options.fetch(:text, "Destroy")
    title = options.fetch(:title,
      "Destroy #{object.class.to_s.tableize.humanize.singularize.downcase} #{object&.name}")
    remote = options.fetch(:remote, false)
    confirm = options.fetch(:confirm,
      "Are you sure you want to destroy this #{object.class.to_s.tableize.humanize.singularize.downcase}?")
    classes = options.fetch(:classes, "")

    classes += " btn btn-danger"

    link_to(text.html_safe,
      polymorphic_path(arr),
      data: {
        confirm: confirm
      },
      method: :delete,
      remote: remote,
      title: title,
      class: classes).html_safe
  end

  def edit_link(object, title: "Edit", classes: "")
    classes += " btn btn-info"
    link_to(title, polymorphic_path([:edit, *object]),
      title: "Edit #{object.class.to_s.humanize}#{" #{object.name}" if object.respond_to?(:name)}", class: classes)
  end

  def current_user_admin_or_owner?(kenshi)
    current_user.present? && (current_user.admin? || kenshi.user.id == current_user.id)
  end
end
