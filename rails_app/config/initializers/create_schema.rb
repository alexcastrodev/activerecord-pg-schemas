# frozen_string_literal: true

Rails.application.config.after_initialize do
  if defined?(Rake)
    Rake::Task["db:create"].enhance do
      Rake::Task["db:create_schema"].invoke
    end
  end
end
