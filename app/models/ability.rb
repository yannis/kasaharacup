# frozen_string_literal: true

class Ability
  include CanCan::Ability

  def initialize(user)
    user ||= User.new
    can :read, Cup
    can :read, Kenshi
    can :read, Team
    can :read, Headline
    # can :create, 'mailing_list'
    can :manage, "mailing_list"
    if user.persisted?
      can [:create, :update, :destroy], Kenshi, user_id: user.id
      can [:create, :update], KenshiForm, user: user
      can :destroy, Participation do |participation|
        participation.kenshi.user_id == user.id
      end
      can :destroy, Purchase do |purchase|
        purchase.kenshi.user_id == user.id
      end
      can [:read, :update, :destroy], User, id: user.id
      if user.admin?
        can :manage, :all
        cannot :register, Cup
      end
      can :register, Cup do |cup|
        cup.registerable?
      end
    end
  end
end
