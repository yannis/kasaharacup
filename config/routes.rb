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
      resources :kenshi_forms, only: %i[new edit create update]

      resources :participations, only: [:destroy]
      resources :purchases, only: [:destroy]
      resources :teams, only: [:index, :show]
      resource :user, only: %i[show destroy] do
        resources :kenshis, only: :destroy
        resources :kenshi_forms, only: %i[new edit create update] do
          member do
            get :duplicate, to: "kenshi_forms#new"
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
    end
    resources :individual_categories do
      resources :documents
      resources :videos
    end
  end
end
