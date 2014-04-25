class Ability
  include CanCan::Ability

  def initialize(user)

    user ||= User.new
    can :read, Kenshi
    can :read, Team
    # can :create, 'mailing_list'
    can :manage, 'mailing_list'
    if user.persisted?
      can [:create, :update, :destroy], Kenshi, user_id: user.id
      # can [:create, :update, :destroy], Kenshi do |kenshi|
      #   Time.current < Kasahara::Application::REGISTRATION_DEADLINE
      # end
      can [:read, :update, :destroy], User, id: user.id
      if user.admin?
        can :manage, :all
      end
    end
  end
end
