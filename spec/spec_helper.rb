require 'json'
require 'nypl_log_formatter'
require 'base64'

require_relative '../lib/avro_decoder'

ENV['LOG_LEVEL'] ||= 'error'
ENV['APP_ENV'] = 'test'
ENV['PLATFORM_API_BASE_URL'] = 'https://example.com/api/v0.1/'
ENV['NYPL_OAUTH_ID'] = Base64.strict_encode64 'fake-client'
ENV['NYPL_OAUTH_SECRET'] = Base64.strict_encode64 'fake-secret'
ENV['NYPL_OAUTH_URL'] = 'https://isso.example.com/'
ENV['NYPL_CORE_S3_BASE_URL'] = 'https://example.com/'
