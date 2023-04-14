# frozen_string_literal: true

Rails.application.routes.draw do
  scope ":locale", locale: /fr|en/, defaults: {locale: "fr"} do |locale|
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
        resources :charges
        resources :kenshis do
          member do
            get :duplicate, to: "kenshis#new"
          end
        end
      end

      namespace :stripe do
        resource :checkout, only: :create
      end
    end

    resources :orders, only: [:show] do
      member do
        get :success
        get :cancel
      end
    end

    resource :user, only: %i[show destroy]

    resource :mailing_list, only: [:new, :destroy]
    root to: "cups#show"
    get "/", to: redirect(Date.current.year.to_s)
  end

  namespace :stripe do
    resource :webhook, only: :create
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
    end
    resources :individual_categories do
      resources :documents
      resources :videos
    end
  end
end
