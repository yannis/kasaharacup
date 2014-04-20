module Translate
  def translate(*attributes)
    attributes.each do |a|
      define_method a.to_s do
        if I18n.locale.to_s == 'fr'
          return eval("#{a.to_s}_fr").blank? ? eval("#{a.to_s}_en") : eval("#{a.to_s}_fr")
        else
          return eval("#{a.to_s}_en")
        end
      end
    end
  end
end

ActiveRecord::Base.extend Translate
