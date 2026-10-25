class PostsController < ApplicationController
  def index
    # The infotable helper will handle rendering the table
  end

  # Demo endpoint for the table's batch actions: shows what the app receives
  def batch
    ids = Array(params[:ids]).join(",")
    # Turbo only follows redirects after non-GET form submissions, like a real app would do
    return redirect_to(batch_posts_path(ids: params[:ids], via: request.request_method), status: :see_other) unless request.get?

    render html: helpers.tag.p("#{params[:via] || request.request_method} ids=#{ids}", id: "batch-result"), layout: "application"
  end
end
