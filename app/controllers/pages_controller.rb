class PagesController < ApplicationController
  def home
    @case_studies = Article.case_study.published.order(:position).limit(3)
  end
end
