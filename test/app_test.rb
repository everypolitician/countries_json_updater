ENV['RACK_ENV'] = 'test'
require 'simplecov'
SimpleCov.start if ENV['COVERAGE']

require 'minitest/autorun'
require 'rack/test'
require 'webmock/minitest'
require 'sidekiq/testing'
Sidekiq::Testing.fake!

require_relative '../app'

describe CountriesJsonUpdater do
  include Rack::Test::Methods

  before do
    CountriesJsonUpdater.everypolitician_data_repo = 'everypolitician/everypolitician-data'
    stub_request(:get, 'https://api.github.com/repos/everypolitician/everypolitician-data/pulls/16585')
      .to_return(body: File.read('test/github_api_response.json'), headers: { 'Content-Type' => 'application/json' })
  end

  def after_teardown
    Sidekiq::Worker.clear_all
  end

  def app
    CountriesJsonUpdater
  end

  def payload
    {
      pull_request_url: 'https://api.github.com/repos/everypolitician/everypolitician-data/pulls/16585'
    }.to_json
  end

  describe 'receiving a webhook' do
    it 'queues up 1 job' do
      post '/', payload, 'CONTENT_TYPE' => 'application/json', 'HTTP_X_EVERYPOLITICIAN_EVENT' => 'pull_request_opened'
      app.jobs.size.must_equal(1)
    end

    it 'passes the branch name to the job' do
      post '/', payload, 'CONTENT_TYPE' => 'application/json', 'HTTP_X_EVERYPOLITICIAN_EVENT' => 'pull_request_opened'
      app.jobs.first['args'].must_equal(["philippines-house-1473176512"])
    end

    it 'ignores pull requests which are being closed' do
      post '/', payload, 'CONTENT_TYPE' => 'application/json', 'HTTP_X_EVERYPOLITICIAN_EVENT' => 'pull_request_closed'
      app.jobs.size.must_equal(0)
    end
  end

  describe 'processing a webhook' do
    subject { CountriesJsonUpdater.new }
    let(:with_git_repo) { Minitest::Mock.new }
    let(:system) { Minitest::Mock.new }

    before do
      with_git_repo.expect(
        :call,
        nil,
        [
          subject.class.everypolitician_data_repo,
          { branch: 'asdf', message: 'Refresh countries.json' }
        ]
      )
      system.expect(:call, nil, [Hash, 'bundle install --quiet --jobs 4 --without test'])
      system.expect(:call, nil, [Hash, 'bundle exec rake countries.json'])
    end

    after do
      with_git_repo.verify
      system.verify
    end

    it 'clones the repo' do
      subject.stub(:with_git_repo, with_git_repo) do
        subject.stub(:system, system) do
          subject.perform('asdf')
        end
      end
    end
  end
end
