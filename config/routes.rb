Rails.application.routes.draw do
  # Authentication
  resource :session
  resources :passwords, param: :token
  resources :registrations, only: [:new, :create]
  resource :settings, only: [:show, :update]

  # Public landing page + main application
  root "home#index"
  get "dashboard", to: "dashboard#index"
  get "dashboard/more_articles", to: "dashboard#more_articles"

  resources :feeds, only: [:index, :new, :create, :destroy] do
    collection do
      post :discover
      post :import_opml
      get :export_opml
      post :refresh_all
    end
  end

  post "mark_onboarding_completed", to: "dashboard#mark_onboarding_completed"

  resources :articles, only: [:index, :show] do
    member do
      patch :toggle_read
      patch :toggle_starred
      patch :toggle_archived
      post :fetch_content
    end
  end

  get "search", to: "articles#search"

  # Daily Briefs
  resources :daily_brief_schedules do
    member do
      post :generate_now
    end
  end
  resources :daily_briefs, only: [:index, :show] do
    member do
      patch :mark_read
      patch :mark_unread
    end
  end

  # Admin section - requires authentication
  mount MissionControl::Jobs::Engine, at: "/admin/jobs"

  namespace :admin do
    get '/', to: 'dashboard#index', as: :root
    get 'dashboard', to: 'dashboard#index'

    resources :users, only: [:index, :update] do
      patch :confirm, on: :member
    end

    resource :litellm_settings, only: [:show, :update] do
      post :test_connection
      post :fetch_models
    end

    resource :settings, only: [:show, :update]

    resources :suggested_feeds

    resources :daily_brief_prompts, only: [:index]
  end

  # API routes
  namespace :api do
    namespace :v1 do
      # Health check
      get 'health', to: 'health#show'

      # Authentication
      post 'auth/login', to: 'auth#login'
      post 'auth/register', to: 'auth#register'
      post 'auth/refresh', to: 'auth#refresh'
      delete 'auth/logout', to: 'auth#logout'

      # Feeds
      resources :feeds, only: [:index, :create, :destroy] do
        collection do
          get :browse
          post :discover
        end
      end

      # Articles
      resources :articles, only: [:index, :show] do
        member do
          patch :mark_read
          patch :mark_starred
          patch :mark_archived
        end
        collection do
          get :search
          get :unread_count
          post :batch_update
          post :mark_all_read
        end
      end

      # Daily Briefs
      resources :daily_briefs, only: [:index, :show] do
        member do
          patch :mark_read
          patch :mark_unread
        end
        collection do
          get :latest
        end
      end
    end
  end

  # Health check
  get "up" => "rails/health#show", as: :rails_health_check
end
