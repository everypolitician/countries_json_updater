require 'json'
require 'webhook_handler'
require 'everypoliticianbot'
require 'sidekiq/api'
require 'dotenv'
Dotenv.load

class CountriesJsonUpdater
  include WebhookHandler
  include Everypoliticianbot::Github

  def self.everypolitician_data_repo
    @everypolitician_data_repo ||= ENV.fetch('EVERYPOLITICIAN_DATA_REPO')
  rescue KeyError => e
    abort "Missing required environment variable: #{e}"
  end

  def self.everypolitician_data_repo=(repo)
    @everypolitician_data_repo = repo
  end

  def handle_webhook
    request.body.rewind
    payload = JSON.parse(request.body.read)
    return unless payload['repository']['full_name'] == self.class.everypolitician_data_repo
    return unless %w(opened synchronize).include?(payload['action'])
    branch = payload['pull_request']['head']['ref']
    if Sidekiq::Queue.new.map(&:args).flatten.include?(branch)
      error = "Existing job found for branch #{branch.inspect}, skipping."
      logger.warn(error)
      return error
    end
    self.class.perform_async(branch)
  end

  def perform(branch)
    message = 'Refresh countries.json'
    options = { branch: branch, message: message }
    with_git_repo(self.class.everypolitician_data_repo, options) do
      # Unset bundler environment variables so it uses the correct Gemfile etc.
      env = {
        'BUNDLE_GEMFILE' => nil,
        'BUNDLE_BIN_PATH' => nil,
        'RUBYOPT' => nil,
        'RUBYLIB' => nil,
        'NOKOGIRI_USE_SYSTEM_LIBRARIES' => '1'
      }
      system(env, 'bundle install --quiet --jobs 4 --without test')
      system(env, 'bundle exec rake countries.json')
    end
  end
end
