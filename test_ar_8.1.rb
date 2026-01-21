# frozen_string_literal: true

require "bundler/inline"

gemfile(true) do
  source "https://rubygems.org"

  gem "rails", "8.1.0"
  gem "pg"
end

require "rails"
require "active_record/railtie"
require "rake"
require "minitest/autorun"
require "yaml"

# Load config from database.yml
db_config = YAML.load_file(File.expand_path("config/database.yml", __dir__))["development"]
DATABASE_NAME = db_config["database"]
SCHEMA_NAME = db_config["schema_search_path"]

DB_CONFIG = {
  adapter: db_config["adapter"],
  encoding: db_config["encoding"],
  username: db_config["username"],
  password: db_config["password"],
  host: db_config["host"],
  port: db_config["port"]
}

class TestApp < Rails::Application
  config.load_defaults 8.0
  config.eager_load = false
  config.logger = Logger.new($stdout)
  config.active_record.maintain_test_schema = false
  config.root = __dir__
  Rails.logger = config.logger
end

Rails.env = "development"

# Initialize Rails
Rails.application.initialize!

# Load custom rake tasks
load File.expand_path("lib/tasks/db_schema.rake", __dir__)

# Recreate database
ActiveRecord::Base.establish_connection(DB_CONFIG.merge(database: "postgres"))
ActiveRecord::Base.connection.execute("DROP DATABASE IF EXISTS #{DATABASE_NAME}")
ActiveRecord::Base.connection.execute("CREATE DATABASE #{DATABASE_NAME}")
puts "Database '#{DATABASE_NAME}' created."

# Reconnect to test database
ActiveRecord::Base.establish_connection(:development)

# Drop schemas (clean slate)
ActiveRecord::Base.connection.execute("DROP SCHEMA IF EXISTS #{SCHEMA_NAME} CASCADE")
ActiveRecord::Base.connection.execute("DROP SCHEMA IF EXISTS public CASCADE")

# Mimic enhance
puts "\n=== Running db:create_schema via Rake task ==="
Rake::Task["db:create_schema"].invoke
puts "Schema created via db:create_schema task."

# Create migration file
MIGRATIONS_PATH = File.expand_path("db/migrate", __dir__)
FileUtils.mkdir_p(MIGRATIONS_PATH)

File.write("#{MIGRATIONS_PATH}/20240101000001_create_users.rb", <<~RUBY)
  class CreateUsers < ActiveRecord::Migration[8.0]
    def change
      create_table :users do |t|
        t.string :name
        t.string :email
        t.timestamps
      end
    end
  end
RUBY

puts "\n=== Running db:migrate ==="
ActiveRecord::MigrationContext.new(MIGRATIONS_PATH).migrate

class User < ActiveRecord::Base
end

class SchemaSearchPathTest < Minitest::Test
  def test_users_table_in_correct_schema
    result = ActiveRecord::Base.connection.execute(<<~SQL)
      SELECT table_schema, table_name
      FROM information_schema.tables
      WHERE table_name = 'users'
    SQL

    schemas = result.map { |r| r["table_schema"] }
    puts "\n\nTable 'users' found in schemas: #{schemas.inspect}"

    assert_includes schemas, SCHEMA_NAME,
      "Table 'users' should be created in '#{SCHEMA_NAME}' schema"
    refute_includes schemas, "public",
      "Table 'users' should NOT be in 'public' schema"
  end

  def test_schema_migrations_in_correct_schema
    result = ActiveRecord::Base.connection.execute(<<~SQL)
      SELECT table_schema, table_name
      FROM information_schema.tables
      WHERE table_name = 'schema_migrations'
    SQL

    schemas = result.map { |r| r["table_schema"] }
    puts "\n\nTable 'schema_migrations' found in schemas: #{schemas.inspect}"

    assert_includes schemas, SCHEMA_NAME,
      "Table 'schema_migrations' should be created in '#{SCHEMA_NAME}' schema"
    refute_includes schemas, "public",
      "Table 'schema_migrations' should NOT be in 'public' schema"
  end

  def test_ar_internal_metadata_in_correct_schema
    result = ActiveRecord::Base.connection.execute(<<~SQL)
      SELECT table_schema, table_name
      FROM information_schema.tables
      WHERE table_name = 'ar_internal_metadata'
    SQL

    schemas = result.map { |r| r["table_schema"] }
    puts "\n\nTable 'ar_internal_metadata' found in schemas: #{schemas.inspect}"

    assert_includes schemas, SCHEMA_NAME,
      "Table 'ar_internal_metadata' should be created in '#{SCHEMA_NAME}' schema"
    refute_includes schemas, "public",
      "Table 'ar_internal_metadata' should NOT be in 'public' schema"
  end

  def test_crud_operations
    user = User.create!(name: "Test", email: "test@example.com")
    assert user.persisted?

    found = User.find(user.id)
    assert_equal "Test", found.name

    puts "\n\nCRUD operations working correctly in '#{SCHEMA_NAME}' schema"
  end
end
