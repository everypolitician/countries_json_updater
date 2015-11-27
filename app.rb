require 'json'

require 'webhook_handler'
require 'everypoliticianbot'
require 'dotenv'
Dotenv.load

class CountriesJsonUpdater
  include WebhookHandler
  include Everypoliticianbot::Github

  begin
    EVERYPOLITICIAN_DATA_REPO = ENV.fetch('EVERYPOLITICIAN_DATA_REPO')
  rescue KeyError => e
    abort "Missing required environment variable: #{e}"
  end

  def handle_webhook
    request.body.rewind
    payload = JSON.parse(request.body.read)
    return unless payload['repository']['full_name'] == EVERYPOLITICIAN_DATA_REPO
    return unless %w(opened synchronize).include?(payload['action'])
    branch = payload['pull_request']['head']['ref']
    self.class.perform_async(branch)
  end

  def perform(branch)
    message = 'Refresh countries.json'
    options = { branch: branch, message: message }
    with_git_repo(EVERYPOLITICIAN_DATA_REPO, options) do
      # Unset bundler environment variables so it uses the correct Gemfile etc.
      env = {
        'BUNDLE_GEMFILE' => nil,
        'BUNDLE_BIN_PATH' => nil,
        'RUBYOPT' => nil,
        'RUBYLIB' => nil,
        'NOKOGIRI_USE_SYSTEM_LIBRARIES' => '1'
      }
      system(env, 'bundle install')
      system(env, 'bundle exec rake countries.json')
    end
  end
end
