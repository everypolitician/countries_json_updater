ENV['RACK_ENV'] = 'test'
require 'simplecov'
SimpleCov.start if ENV['COVERAGE']

require 'minitest/autorun'
require 'rack/test'
require 'sidekiq/testing'
Sidekiq::Testing.fake!

require_relative '../app'

describe CountriesJsonUpdater do
  include Rack::Test::Methods

  def after_teardown
    Sidekiq::Worker.clear_all
  end

  def app
    CountriesJsonUpdater
  end

  def payload
    @payload ||= File.read(File.expand_path('../example_payload.json', __FILE__))
  end

  describe 'handling a webhook' do
    it 'queues up 1 job' do
      post '/', payload, 'CONTENT_TYPE' => 'application/json'
      app.jobs.size.must_equal(1)
    end

    it 'passes the branch name to the job' do
      post '/', payload, 'CONTENT_TYPE' => 'application/json'
      app.jobs.first['args'].must_equal(["turkey-assembly-1448607229"])
    end

    it 'ignores pull requests for other repositories' do
      payload2 = JSON.parse(payload)
      payload2['repository']['full_name'] = 'foo/bar'
      post '/', JSON.generate(payload2), 'CONTENT_TYPE' => 'application/json'
      app.jobs.size.must_equal(0)
    end

    it 'ignores pull requests which are being closed' do
      payload2 = JSON.parse(payload)
      payload2['action'] = 'closed'
      post '/', JSON.generate(payload2), 'CONTENT_TYPE' => 'application/json'
      app.jobs.size.must_equal(0)
    end
  end
end
