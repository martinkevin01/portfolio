require_relative "boot"

require "rails/all"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module Portfolio
  class Application < Rails::Application
    config.generators do |generate|
      generate.assets false
      generate.helper false
      generate.test_framework :test_unit, fixture: false
    end

    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 7.0

    # The Zafem feature and its tests use Redis, not the database.
    # When running tests on a Heroku one-off dyno, there is no test database available,
    # causing `maintain_test_schema!` to fail.
    # This line disables the database schema check for the test environment.
    config.active_record.maintain_test_schema = false if Rails.env.test?

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    # config.time_zone = "Central Time (US & Canada)"
    # config.eager_load_paths << Rails.root.join("extras")
  end
end
