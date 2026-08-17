module Admin
  # ApplicationController already adds `before_action :require_authentication`
  # (see app/controllers/concerns/authentication.rb) and every visitor-facing
  # controller has to opt out of it. Admin::BaseController intentionally does
  # NOT opt out — that's the whole auth gate for the CMS.
  class BaseController < ApplicationController
    layout "admin"
  end
end
