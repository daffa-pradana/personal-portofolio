class Project < ApplicationRecord
  default_scope { order(:position) }

  validates :title, presence: true
end
