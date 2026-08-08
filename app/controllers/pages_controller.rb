class PagesController < ApplicationController
  def home
    @case_studies = Article.case_study.published
                           .with_attached_cover_image
                           .order(:position)
                           .limit(3)
  end
end
