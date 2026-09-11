module Admin
  # No new/create/destroy: site settings are a fixed registry of keys seeded
  # from db/seeds/site_settings.yml (see SiteSetting model docs). Editing an
  # existing key's value is all this needs.
  class SiteSettingsController < BaseController
    def index
      @site_settings = SiteSetting.order(:key)
    end

    def update
      site_setting = SiteSetting.find(params[:id])

      if site_setting.update(site_setting_params)
        redirect_to admin_site_settings_path, notice: "Site setting updated."
      else
        redirect_to admin_site_settings_path, alert: site_setting.errors.full_messages.to_sentence
      end
    end

    private
      def site_setting_params
        params.expect(site_setting: [ :value ])
      end
  end
end
