# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).
#
# Example:
#
#   ["Action", "Comedy", "Drama", "Horror"].each do |genre_name|
#     MovieGenre.find_or_create_by!(name: genre_name)
#   end

# Seed helper — reads a YAML file from db/seeds/ and upserts records.
# Usage: seed_from_yaml(Project, "projects.yml", find_by: :title)
def seed_from_yaml(model, filename, find_by:)
  records = YAML.load_file(Rails.root.join("db/seeds", filename))
  records.each do |attrs|
    record = model.find_or_initialize_by(find_by => attrs[find_by.to_s])
    record.assign_attributes(attrs)
    record.save!
  end
end

seed_from_yaml(Project, "projects.yml", find_by: :title)
