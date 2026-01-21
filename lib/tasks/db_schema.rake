# frozen_string_literal: true

namespace :db do
  desc "Create PostgreSQL schema if it doesn't exist (based on schema_search_path)"
  task :create_schema do
    config = ActiveRecord::Base.connection_db_config.configuration_hash
    schema_search_path = config[:schema_search_path]

    if schema_search_path.present?
      schemas = schema_search_path.split(",").map(&:strip)

      schemas.each do |schema_name|
        next if schema_name == "public"

        ActiveRecord::Base.connection.execute("CREATE SCHEMA IF NOT EXISTS #{schema_name}")
        puts "Schema '#{schema_name}' created (or already exists)."
      end
    else
      puts "No schema_search_path configured, skipping schema creation."
    end
  end
end

# This will only work on Rails Application
# Rake::Task["db:create"].enhance do
#   Rake::Task["db:create_schema"].invoke
# end
