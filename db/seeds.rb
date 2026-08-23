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
#
# `update_existing: false` only creates rows that are missing and leaves
# existing ones untouched. Use it for anything a human edits through the admin
# UI — re-seeding must not silently revert their changes.
#
# `prune: true` also deletes rows whose `find_by` value is absent from the
# YAML, making the file the single source of truth rather than an append-only
# feed. Only safe when nothing else writes to the table — see the call sites.
def seed_from_yaml(model, filename, find_by:, update_existing: true, prune: false)
  records = YAML.load_file(Rails.root.join("db/seeds", filename))

  records.each do |attrs|
    record = model.find_or_initialize_by(find_by => attrs[find_by.to_s])
    next if record.persisted? && !update_existing

    record.assign_attributes(attrs)
    record.save!
  end

  return unless prune

  stale = model.where.not(find_by => records.map { |attrs| attrs[find_by.to_s] })
  return if stale.none?

  # Deleting seed data is worth announcing rather than doing silently.
  puts "Pruned #{stale.count} #{model.name.underscore.humanize.downcase} row(s) " \
       "no longer in #{filename}: #{stale.pluck(find_by).join(", ")}"
  stale.destroy_all
end

seed_from_yaml(Article, "articles.yml", find_by: :slug)

# The knowledge base is what the AI chat recites to visitors, so the YAML is
# the single source of truth and seeding prunes anything not in it. Without
# that, rewording an entry's title orphans the old row instead of updating it,
# and the model ends up grounded in both versions at once — which is exactly
# how the bot starts contradicting itself about basic facts.
#
# Revisit if Batch 4 adds admin CRUD for knowledge entries: at that point rows
# could legitimately originate outside this file, and pruning would delete
# them. A stable key column (as Article uses `slug`) would be the fix.
seed_from_yaml(KnowledgeEntry, "knowledge_entries.yml", find_by: :title, prune: true)

# Site settings are edited through the admin UI, so seeding only ever creates
# the missing keys with their defaults — it never overwrites a value Daffa set.
seed_from_yaml(SiteSetting, "site_settings.yml", find_by: :key, update_existing: false)

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
