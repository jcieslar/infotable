class PostsController < ApplicationController
  def index
    # The infotable helper will handle rendering the table
  end

  # Demo endpoint for the table's batch actions: shows what the app receives
  def batch
    render plain: "#{request.request_method} ids=#{Array(params[:ids]).join(",")}"
  end
end
