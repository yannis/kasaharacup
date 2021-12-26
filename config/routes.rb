# frozen_string_literal: true

Rails.application.routes.draw do
  devise_for :users, ActiveAdmin::Devise.config
  scope ":locale", locale: /fr|en/ do |locale|
    resources :cups, only: [:index, :show]
    #  do
    # resources :headlines, only: [:index, :show]
    # resources :kenshis do
    #   get :autocomplete_kenshi_club, on: :collection
    # end

    # resources :participations, only: [:destroy]
    # resources :purchases, only: [:destroy]
    # resources :teams, only: [:index, :show]
    # resources :users do
    #   resources :charges
    #   resources :kenshis do
    #     member do
    #       get :duplicate, to: "kenshis#new"
    #     end
    #   end
    # end
    # end

    # resources :users

    resource :mailing_list, only: [:new, :destroy]
    root to: "cups#show"
    get "/", to: redirect(Date.current.year.to_s)
  end

  get "/", to: redirect(I18n.locale.to_s)
  ActiveAdmin.routes(self)
end
