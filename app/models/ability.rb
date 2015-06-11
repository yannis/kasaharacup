class Ability
  include CanCan::Ability

  def initialize(user)

    user ||= User.new
    can :read, Kendocup::Cup
    can :read, Kendocup::Kenshi
    can :read, Kendocup::Team
    can :read, Kendocup::Headline
    # can :create, 'mailing_list'
    can :manage, 'mailing_list'
    if user.persisted?
      can [:create, :update, :destroy], Kendocup::Kenshi, user_id: user.id
      # can [:create, :update, :destroy], Kenshi do |kenshi|
      #   Time.current < Kasahara::Application::REGISTRATION_DEADLINE
      # end
      can [:destroy], Kendocup::Participation do |participation|
        participation.kenshi.user_id == user.id
      end
      can [:destroy], Kendocup::Purchase do |purchase|
        purchase.kenshi.user_id == user.id
      end
      can [:read, :update, :destroy], User, id: user.id
      if user.admin?
        can :manage, :all
      end
    end
  end
end
