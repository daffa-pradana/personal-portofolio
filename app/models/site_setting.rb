class SiteSetting < ApplicationRecord
  validates :key, presence: true, uniqueness: true

  normalizes :key, with: ->(k) { k.to_s.strip.downcase }

  # Reads a setting's value, or nil when the key is missing or its value is
  # blank. Blank and missing deliberately collapse into the same answer: callers
  # only ever ask "is this configured?", and an empty row is not configured.
  #
  #   SiteSetting[:cv_url] # => "https://..." or nil
  def self.[](key)
    find_by(key: key.to_s)&.value.presence
  end

  def self.[]=(key, value)
    setting = find_or_initialize_by(key: key.to_s)
    setting.value = value
    setting.save!
    value
  end
end
