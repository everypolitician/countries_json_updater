source 'https://rubygems.org'

ruby '2.2.3'
git_source(:github) { |repo_name| "https://github.com/#{repo_name}.git" }

gem 'dotenv'
gem 'everypoliticianbot', github: 'everypolitician/everypoliticianbot'
gem 'pry'
gem 'puma'
gem 'rake'
gem 'sinatra', require: false
gem 'webhook_handler', '~> 0.4.0'

group :test do
  gem 'minitest'
  gem 'rack-test'
  gem 'simplecov'
  gem 'webmock'
end
