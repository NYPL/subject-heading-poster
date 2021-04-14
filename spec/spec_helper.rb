require 'json'
require 'nypl_log_formatter'
require 'base64'

require_relative '../app'
require_relative '../lib/avro_decoder'
require_relative '../lib/bib_data_manager'

ENV['LOG_LEVEL'] ||= 'error'
ENV['APP_ENV'] = 'test'
ENV['PLATFORM_API_BASE_URL'] = 'https://example.com/api/v0.1/'
ENV['NYPL_OAUTH_ID'] = Base64.strict_encode64 'fake-client'
ENV['NYPL_OAUTH_SECRET'] = Base64.strict_encode64 'fake-secret'
ENV['NYPL_OAUTH_URL'] = 'https://isso.example.com/'
ENV['NYPL_CORE_S3_BASE_URL'] = 'https://example.com/'
ENV['SHEP_API_BIBS_ENDPOINT'] = 'https://example/shep_api/bib'
ENV['PARALLEL_PROCESSES'] = '2'

def minimal_bib_data(snake_case: true)
  bare_bib_data = {
    'id' => '123456',
    'title' => 'Minimal bib',
    'lang' => JSON.dump({ 'code' => 'eng' })
  }

  var_fields_key = snake_case ? 'var_fields' : 'varFields'
  nypl_source_key = snake_case ? 'nypl_source' : 'nyplSource'

  bare_bib_data[var_fields_key] = JSON.dump({})
  bare_bib_data[nypl_source_key] = 'sierra_nypl'
  bare_bib_data
end

def minimal_bib_data_manager(snake_case: true)
  SHEP::BibDataManager.new(minimal_bib_data(snake_case: snake_case))
end
