class ReviewsController < ApplicationController
  before_action :load_explicit_subject

  def index
    @review = scope.new
    @reviews = scope.all
  end

  def create
    @review = scope.new(review_params)

    if @review.save
      @review.send_feedback_request
      redirect_to reviews_path
    else
      render action: :index
    end
  end

private

  def review_params
    params.require(:review).
      permit(:author_email, :author_name, :relationship)
  end

  def scope
    (@subject || current_user).reviews_received
  end

  def load_explicit_subject
    if params[:user_id]
      @subject = current_user.managees.find(params[:user_id])
    end
    true
  end
end