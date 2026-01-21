# frozen_string_literal: true

namespace :db do
  desc "Create PostgreSQL schemas for all database configurations"
  task create_schema: :environment do
    environments = [Rails.env]

    # In development, also create schemas for test environment
    # bc db:prepare also runs for the test environment, and the custom_schema is not being created in the test database
    environments << "test" if Rails.env.development?
    environments.each do |env_name|
      ActiveRecord::Base.configurations.configs_for(env_name: env_name).each do |db_config|
        schema_search_path = db_config.configuration_hash[:schema_search_path]

        next if schema_search_path.blank?

        schemas = schema_search_path.split(",").map(&:strip)

        ActiveRecord::Base.establish_connection(db_config)

        schemas.each do |schema_name|
          # Ignore public, right ? lesgo 
          # (e.g schema_search_path: public,tenant_abc)
          next if schema_name == "public"

          ActiveRecord::Base.connection.execute("CREATE SCHEMA IF NOT EXISTS #{schema_name}")
          puts "Schema '#{schema_name}' created for #{db_config.name} in #{env_name} (or already exists)."
        end
      end
    end

    # Reconnect to primary
    ActiveRecord::Base.establish_connection(:primary)
  end
end
