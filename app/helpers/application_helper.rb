module ApplicationHelper

  def mandatory_fields
    "<p class='mandatory_fields'><span class='red_star'>*</span> #{t('layout.form.mandatory')}</p>".html_safe
  end

  def title(content, options={page_title: true, meta_title: true})
    content_for(:title) {content} if options[:page_title]
    content_for(:header_title){ content_tag( :header, content_tag(:h1, content))} if options[:meta_title]
  end

  def submit_or_cancel_form(f, text=nil)
    link = [f.submit(text, class: 'btn btn-success')]
    link << t("form.or")
    link << link_to(t("form.cancel"), (session[:return_to].nil? ? root_path : session[:return_to]), accesskey: 'ESC', title: "Cancel #{f.object_name} form", class: "cancel #{request.format == 'application/javascript' ? 'close_div' : ''}")
    link.join(' ').html_safe
  end

  def destroy_link(object,
    text: "<span class='glyphicon glyphicon-trash'></span> Destroy",
    title: "Destroy #{object.class.to_s.tableize.humanize.singularize.downcase}#{' "'+object.name+'"' if object.respond_to?(:name)}",
    remote: false,
    confirm: "Are you sure you want to destroy this #{object.class.to_s.tableize.humanize.singularize.downcase}?",
    classes: "")
    classes += " btn btn-danger"
    link_to(text.html_safe,
        polymorphic_path(object),
        data: {
          confirm: confirm
        },
        method: :delete,
        remote: remote,
        title: title,
        class: classes
    ).html_safe
  end

  def edit_link(object, title: "Edit", classes: "")
    classes += ' btn btn-info'
    link_to( "<span class='glyphicon glyphicon-edit'></span> #{title}".html_safe, polymorphic_path([:edit, object]), title: "Edit #{object.class.to_s.humanize}#{object.respond_to?(:name) ? " #{object.name}" : ''}", class: classes)
  end
end
