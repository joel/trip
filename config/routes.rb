Rails.application.routes.draw do
  resources :users
  resource :account, only: %i[show edit update destroy]
  get "welcome/home"

  # Access & onboarding
  get "request-access", to: "access_requests#new", as: :new_access_request
  post "request-access", to: "access_requests#create", as: :submit_access_request
  resources :access_requests, only: [:index] do
    member do
      patch :approve
      patch :reject
    end
  end
  resources :invitations, only: %i[index new create]

  # Notifications
  resources :notifications, only: [:index] do
    member do
      patch :mark_as_read
    end
    collection do
      patch :mark_all_as_read
    end
  end

  # Core domain
  resources :trips do
    resources :journal_entries, except: %i[index show] do
      resource :subscription,
               only: %i[create destroy],
               controller: "journal_entry_subscriptions"
      resources :comments, only: %i[create update destroy]
      resources :reactions, only: %i[create destroy]
    end
    resources :checklists do
      resources :checklist_sections, only: %i[create destroy]
      resources :checklist_items, only: %i[create destroy] do
        member do
          patch :toggle
        end
      end
    end
    resources :trip_memberships, only: %i[index new create destroy],
                                 path: "members"
    resources :exports, only: %i[index new create show] do
      member do
        get :download
      end
    end
    member do
      patch :transition
    end
  end
  # Google One Tap sign-in
  post "auth/google/one_tap", to: "google_one_tap_sessions#create"

  # MCP (Model Context Protocol) server endpoint
  post "/mcp", to: "mcp#handle"

  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/*
  get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Defines the root path route ("/")
  root "welcome#home"

  get "test/login" => "test_sessions#show", as: :test_login if Rails.env.test?
end
