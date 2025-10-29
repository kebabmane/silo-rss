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
        @feed.save
        FeedRefreshJob.perform_later(@feed.id)
      end

      @existing_categories = Current.user.subscriptions.distinct.pluck(:category).compact.sort

      render turbo_stream: turbo_stream.replace("feed_discovery", partial: "feeds/discovered_feed", locals: { feed: @feed, existing_categories: @existing_categories })
    else
      render turbo_stream: turbo_stream.replace("feed_discovery", partial: "feeds/discovery_error")
    end
  end

  def create
    @feed = Feed.find(params[:feed_id])
    @subscription = Current.user.subscriptions.build(
      feed: @feed,
      category: params[:category],
      custom_name: params[:custom_name]
    )

    if @subscription.save
      redirect_to dashboard_path, notice: "Feed added successfully"
    else
      render :new, status: :unprocessable_entity
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
  rescue => e
    Rails.logger.error("OPML import failed: #{e.message}")
    redirect_to feeds_path, alert: "Failed to import OPML file."
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

    redirect_to feeds_path, alert: "Feed not found."
    throw :abort
  end

  def subscription_params
    params.require(:subscription).permit(:category, :custom_name)
  end

  def fetch_initial_metadata(feed)
    uri = UrlSafety.safe_uri_for(feed.feed_url)
    return unless uri

    response = HTTParty.get(uri.to_s, timeout: 10)
    parsed_feed = Feedjira.parse(response.body)
    if parsed_feed&.title.present? && feed.title.blank?
      feed.title = parsed_feed.title
    end
  rescue => e
    Rails.logger.warn("Feed discovery metadata fetch failed for #{feed.feed_url}: #{e.message}")
  end
end
