# frozen_string_literal: true

Rails.application.routes.draw do
  scope ":locale", locale: /#{I18n.available_locales.join("|")}/ do |locale|
    devise_for :user, controllers: {registrations: "users/registrations"}
    devise_scope :user do
      get "log_out", to: "devise/sessions#destroy"
    end
    get "/about", to: "static_pages#about"
    resources :cups, only: [:index, :show] do
      resources :headlines, only: [:index, :show]
      resources :kenshis do
        get :autocomplete_kenshi_club, on: :collection
      end

      resources :participations, only: [:destroy]
      resources :purchases, only: [:destroy]
      resources :teams, only: [:index, :show]
      resource :user, only: %i[show destroy] do
        resources :kenshis do
          member do
            get :duplicate, to: "kenshis#new"
          end
        end
      end
      resource :waiver, only: %i[show]
    end

    resource :user, only: %i[show destroy]

    resource :mailing_list, only: [:new, :destroy]
    root to: "cups#show"
    get "/", to: redirect(Date.current.year.to_s)
  end

  get "/", to: redirect(I18n.locale.to_s)

  if Rails.env.development?
    mount Lookbook::Engine, at: "/styleguide"
    mount LetterOpenerWeb::Engine, at: "/emails"
  end
  ActiveAdmin.routes(self)
  namespace :admin do
    resources :team_categories do
      resources :documents
      resources :videos
      resources :pool_memberships, only: :update, module: :team_categories
      resources :encounters, only: [:index, :new, :create, :show] do
        resource :lineup, only: :update, module: :encounters
        resource :team_swap, only: :create, module: :encounters
        resource :lineup_seed, only: :create, module: :encounters
        resource :daihyosen, only: :update, module: :encounters
        resources :team_fights, only: [:update] do
          resources :team_fight_points, only: [:create, :destroy]
        end
      end
    end
    resources :individual_categories do
      post :generate_bracket, on: :member, to: "competition_trees#generate_bracket"
      post :generate_pool_fights, on: :member, to: "pool_fights#generate"
      post :regenerate_pool_fights, on: :member, to: "pool_fights#regenerate"
      resources :fights, only: [:update] do
        resources :fight_points, only: [:create, :destroy]
      end
      resources :pool_fights, only: [:create, :update, :destroy] do
        resources :fight_points, only: [:create, :destroy]
      end
      resources :pool_memberships, only: :update, module: :individual_categories
      resources :documents
      resources :videos
    end
  end
end
