class HomeController < ApplicationController
  allow_unauthenticated_access only: :index

  def index
    # Resume existing session so returning users go straight to their reader
    if resume_session
      redirect_to dashboard_path and return
    end
  end
end
