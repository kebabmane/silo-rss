class FeedsController < ApplicationController
  OPML_UPLOAD_LIMIT = 1.megabyte

  before_action :set_feed, only: [:destroy]

  def index
    @subscriptions = Current.user.subscriptions.includes(:feed).order(:category, :custom_name)
  end

  def new
    @subscription = Subscription.new
  end

  def discover
    url = params[:url]
    discovery_result = FeedDiscoveryService.new(url).discover

    if discovery_result
      @feed = Feed.find_or_initialize_by(feed_url: discovery_result[:feed_url])

      if @feed.new_record?
        @feed.site_url = discovery_result[:site_url]
        fetch_initial_metadata(@feed)
        @feed.title = (URI.parse(@feed.feed_url).host rescue "Unknown Feed") if @feed.title.blank?
        @feed.save
      end

      FeedRefreshJob.perform_later(@feed.id)

      @existing_categories = Current.user.subscriptions.distinct.pluck(:category).compact.sort

      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: turbo_stream.replace("feed_discovery", partial: "feeds/discovered_feed", locals: { feed: @feed, existing_categories: @existing_categories }), formats: :turbo_stream
        end
        format.html do
          render turbo_stream: turbo_stream.replace("feed_discovery", partial: "feeds/discovered_feed", locals: { feed: @feed, existing_categories: @existing_categories }), formats: :turbo_stream
        end
      end
    else
      respond_to do |format|
        format.turbo_stream { render turbo_stream: turbo_stream.replace("feed_discovery", partial: "feeds/discovery_error"), formats: :turbo_stream }
        format.html { render turbo_stream: turbo_stream.replace("feed_discovery", partial: "feeds/discovery_error"), formats: :turbo_stream }
      end
    end
  rescue SocketError, Timeout::Error, Errno::ECONNREFUSED, HTTParty::Error, Feedjira::NoParserAvailable, URI::InvalidURIError => e
    Rails.logger.warn("Feed discovery error: #{e.message}")
    respond_to do |format|
      format.turbo_stream { render turbo_stream: turbo_stream.replace("feed_discovery", partial: "feeds/discovery_error"), formats: :turbo_stream }
      format.html { render turbo_stream: turbo_stream.replace("feed_discovery", partial: "feeds/discovery_error"), formats: :turbo_stream }
    end
  end

  def create
    @feed = find_or_create_feed_from_params
    unless @feed
      respond_to do |format|
        format.html { redirect_to dashboard_path, alert: "Feed not found" }
        format.json { render json: { error: "Feed not found" }, status: :not_found }
      end
      return
    end

    @subscription = Current.user.subscriptions.find_by(feed: @feed)

    if @subscription
      # Idempotent: return success for existing subscriptions
      respond_to do |format|
        format.html { redirect_to dashboard_path, notice: "Feed added successfully" }
        format.json { render json: { status: "already_subscribed", feed_id: @feed.id }, status: :ok }
        format.turbo_stream { head :ok }
      end
      return
    end

    @subscription = Current.user.subscriptions.build(feed: @feed, category: params[:category], custom_name: params[:custom_name])

    if @subscription.save
      FeedRefreshJob.perform_later(@feed.id)
      respond_to do |format|
        format.html { redirect_to dashboard_path, notice: "Feed added successfully" }
        format.json { render json: { status: "subscribed", feed_id: @feed.id }, status: :created }
        format.turbo_stream { head :created }
      end
    else
      respond_to do |format|
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: { errors: @subscription.errors.full_messages }, status: :unprocessable_entity }
        format.turbo_stream { head :unprocessable_entity }
      end
    end
  end

  def destroy
    @subscription = Current.user.subscriptions.find_by(feed: @feed)

    unless @subscription
      redirect_to feeds_path, alert: "Feed not found."
      return
    end

    @subscription.destroy
    redirect_to feeds_path, notice: "Feed removed"
  end

  def import_opml
    file = params[:opml_file]

    if file.blank?
      redirect_to feeds_path, alert: "Please select an OPML file"
      return
    end

    if file.size.to_i > OPML_UPLOAD_LIMIT
      redirect_to feeds_path, alert: "OPML file is too large. Maximum size is #{ActiveSupport::NumberHelper.number_to_human_size(OPML_UPLOAD_LIMIT)}."
      return
    end

    count = OpmlService.import(Current.user, file)
    redirect_to dashboard_path, notice: "Successfully imported #{count} feeds"
  rescue Nokogiri::XML::SyntaxError, ArgumentError => e
    Rails.logger.error("OPML import failed: #{e.message}")
    redirect_to feeds_path, alert: "Failed to import OPML file. Please ensure it's a valid OPML format."
  end

  def refresh_all
    UserFeedRefreshJob.perform_later(Current.user.id)
    redirect_back fallback_location: dashboard_path, notice: "Sync started. Your feeds will refresh shortly."
  end

  def export_opml
    opml_content = OpmlService.export(Current.user)
    send_data opml_content,
              filename: "silo_export_#{Date.current}.opml",
              type: "text/xml"
  end

  private

  def set_feed
    @feed = Current.user.feeds.find_by(id: params[:id])
    return if @feed

    # If the feed exists but not subscribed, redirect for HTML, 404 otherwise.
    feed_exists = Feed.exists?(id: params[:id])
    respond_to do |format|
      format.html do
        if feed_exists
          redirect_to feeds_path, alert: "Feed not found."
        else
          head :not_found
        end
      end
      format.any { head(feed_exists ? :not_found : :not_found) }
    end
  end

  def subscription_params
    params.require(:subscription).permit(:category, :custom_name)
  end

  def find_or_create_feed_from_params
    # First try to find an existing Feed
    feed = Feed.find_by(id: params[:feed_id])
    return feed if feed

    # If not found, check if it's a SuggestedFeed ID
    suggested_feed = SuggestedFeed.find_by(id: params[:feed_id])
    return nil unless suggested_feed

    # Create or find a Feed from the SuggestedFeed's URL
    feed = Feed.find_or_initialize_by(feed_url: suggested_feed.feed_url)
    if feed.new_record?
      feed.title = suggested_feed.title
      feed.site_url = suggested_feed.site_url
      fetch_initial_metadata(feed)
      feed.title = (URI.parse(feed.feed_url).host rescue "Unknown Feed") if feed.title.blank?
      feed.save
    end
    feed
  end

  def fetch_initial_metadata(feed)
    FeedFetcherService.new(feed).fetch_metadata
  end
end
