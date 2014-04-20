module FormHelper

  # include SpanErrorMessages

  def self.included(base)
    ActionView::Helpers::FormBuilder.instance_eval do
      include FormBuilderMethods
    end
  end

  module FormBuilderMethods

    def starred_label(method, text = nil, options = {})
      @object = options[:object].nil? ? @object : options[:object]
      error_message = @object.errors[method.to_sym] if @object
      text = text.nil? ? method.to_s.humanize.capitalize : text
      text << "<span class='red_star'>*</span>" if @object.class.validators_on(method).map(&:class).include?(ActiveModel::Validations::PresenceValidator)
      return @template.label(@object_name, method, text.html_safe)
    end

    def label_with_errors(method, text = nil, options = {})
      error_message = @object.errors[method] if @object
      new_class = options[:class] ? options[:class] : ''
      text2 = text.nil? ? method.to_s.humanize.capitalize : text
      text3 = error_message.blank? ? text2 : (text2+': '+error_message+'!')
      @template.label @object_name, method, text3
    end

    def my_error_message_on(method, options = {})
      @object = options[:object].nil? ? @object : options[:object]
      if @object.errors[method.to_sym].blank?
        return nil
      else
        message = "<span class='error_message'>"
        message << method.to_s.capitalize
        message << ' '+@object.errors[method.to_sym].first
        message << "</span>"
        return message.html_safe
      end
    end

    def label_with_errors_and_remote_link_to_add_object(method, index=nil, origin_index=nil, text = nil, title=nil, options = {})
      label = label_with_errors(method, text = nil, options = {})
      loader_id = "loader_new_#{method}#{index.nil? ? '' : '_'+index.to_s}#{origin_index.nil? ? '' : ('_'+origin_index.to_s)}"
      link_id = "create_#{method}#{index.nil? ? '' : '_'+index.to_s}#{origin_index.nil? ? '' : ('_'+origin_index.to_s)}"
      loader = @template.image_tag('ajax-loader.gif', style: 'display: none', id: loader_id)

      href = "/#{method.to_s.humanize.underscore.pluralize}/new"
      options = {url: href, remote: true, before: "Element.hide('#{link_id}'); Element.show('#{loader_id}')", complete: "Element.hide('#{loader_id}'); Element.show('#{link_id}')" , method: :get}
      opt = ["origin=#{@object_name.to_s.gsub('[','_').gsub(']','')}"]
      opt << "index=#{index}" unless index.nil?
      opt << "origin_index=#{origin_index}" unless origin_index.nil?
      options[:with] = "'"+opt.join('&')+"'"
      link = @template.link_to("(+)", options, {id: "#{link_id}", href: href, title: title})
      link = link+loader

      return "<div class='label_and_remote_link'>#{label+' '+link}</div>".html_safe
    end

    def grouped_collection_select(method, collection, sub_name, group_method="name", unit_id="id", unit_name="name")
      @template.select_tag "#{@object_name}[#{method}]",
         @template.option_groups_from_collection_for_select(collection, sub_name, group_method, unit_id, unit_name, @object.send(method)), id: "#{@object_name}_#{method}"
    end
  end
end
