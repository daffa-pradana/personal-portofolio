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
# Usage: seed_from_yaml(Article, "articles.yml", find_by: :slug)
def seed_from_yaml(model, filename, find_by:)
  records = YAML.load_file(Rails.root.join("db/seeds", filename))
  records.each do |attrs|
    record = model.find_or_initialize_by(find_by => attrs[find_by.to_s])
    record.assign_attributes(attrs)
    record.save!
  end
end

seed_from_yaml(Article, "articles.yml", find_by: :slug)

# The admin user is the one exception to the "seed data lives in db/seeds/*.yml"
# convention: a password can't be committed to the repo. Credentials come from
# the environment instead, and seeding does nothing when they're absent, so
# `db:seed` stays safe to run anywhere.
#
#   ADMIN_EMAIL=you@example.com ADMIN_PASSWORD=... bin/rails db:seed
#
# Re-running with a different ADMIN_PASSWORD resets that user's password, which
# is also how to recover from a forgotten one in development.
admin_email = ENV["ADMIN_EMAIL"].presence
admin_password = ENV["ADMIN_PASSWORD"].presence

if admin_email && admin_password
  admin = User.find_or_initialize_by(email_address: admin_email)
  admin.password = admin_password
  admin.save!
  puts "Seeded admin user: #{admin.email_address}"
else
  puts "Skipped admin user — set ADMIN_EMAIL and ADMIN_PASSWORD to create one."
end
