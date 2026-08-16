class PagesController < ApplicationController
  # The landing page is the public face of the site. Authentication exists only
  # to gate the admin CMS, so every visitor-facing controller has to opt out of
  # the `require_authentication` before_action that ApplicationController adds.
  allow_unauthenticated_access

  def home
    @case_studies = Article.case_study.published
                           .with_attached_cover_image
                           .order(:position)
                           .limit(3)

    @cv_url = SiteSetting[:cv_url]
  end
end
