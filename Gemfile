source "https://rubygems.org"
git_source(:github) { |repo| "https://github.com/#{repo}.git" }

# Specify your gem's dependencies in event_engine.gemspec.
gemspec

gem "the_local"

group :development, :test do
  # The dummy app under test/dummy boots a full Rails app
  gem "rails", ">= 7.1.6", "< 9"
  # Needed for the dummy app database
  gem "sqlite3"
  gem "sprockets-rails"
  gem "pry"
  gem "pry-byebug"
  gem "minitest", "~> 5.0"  # pin to 5.x; minitest 6 removed minitest/mock
  gem "minitest-reporters"
  gem "minitest-focus"
  gem "diffy"
  gem "webmock"
end


# Start debugger with binding.b [https://github.com/ruby/debug]
# gem "debug", ">= 1.0.0"
