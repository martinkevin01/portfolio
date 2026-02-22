Rails.application.routes.draw do
  root to: "pages#home"
  match 'download', to: 'pages#download', as: 'download', via: :get
  resources :contacts, only: [:new, :create]

  # Zafem ticket verification
  get 'zafem', to: 'zafem#index'
  post 'zafem/verify', to: 'zafem#verify'
  post 'zafem/reset', to: 'zafem#reset'
  get 'zafem/status', to: 'zafem#status'
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Defines the root path route ("/")
  # root "articles#index"
end
