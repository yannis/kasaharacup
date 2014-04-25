module ActsAsFighter

  def self.included(base)
    base.extend(ClassMethods)
  end

  module ClassMethods
    def acts_as_fighter
      include InstanceMethods
      has_many :fights#, dependent: :destroy
      # validates_presence_of :first_name, :last_name, :email, :address, :zip_code, :city, :country
      # validates_uniqueness_of :last_name, if: Proc.new{|r| Registration.where(last_name: r.last_name, first_name: r.first_name, paid: true).count > 0 }, message: "A paid registration for “%{value}” already exist"
    end

    # def booking_callback(request)
    #   BookingCallback.new(request, self)
    # end
  end

  module InstanceMethods
    def win_fight(fight)
      fight.update_attributes winner: self
    end
  end
end

ActiveRecord::Base.send(:include, ActsAsFighter) if ActiveRecord
