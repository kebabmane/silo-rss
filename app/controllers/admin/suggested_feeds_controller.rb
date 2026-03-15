class Admin::SuggestedFeedsController < AdminController
  before_action :set_suggested_feed, only: [:edit, :update, :destroy]

  def index
    @suggested_feeds = SuggestedFeed.ordered
    @categories = SuggestedFeed.categories
  end

  def new
    @suggested_feed = SuggestedFeed.new
    @categories = SuggestedFeed.categories
  end

  def create
    @suggested_feed = SuggestedFeed.new(suggested_feed_params)

    if @suggested_feed.save
      redirect_to admin_suggested_feeds_path, notice: "Suggested feed added successfully."
    else
      @categories = SuggestedFeed.categories
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @categories = SuggestedFeed.categories
  end

  def update
    if @suggested_feed.update(suggested_feed_params)
      redirect_to admin_suggested_feeds_path, notice: "Suggested feed updated successfully."
    else
      @categories = SuggestedFeed.categories
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @suggested_feed.destroy
    redirect_to admin_suggested_feeds_path, notice: "Suggested feed removed successfully."
  end

  private

  def set_suggested_feed
    @suggested_feed = SuggestedFeed.find(params[:id])
  end

  def suggested_feed_params
    params.require(:suggested_feed).permit(:title, :feed_url, :category, :description, :display_order)
  end
end
