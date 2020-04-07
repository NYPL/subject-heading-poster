require 'json'
require 'nypl_log_formatter'

require_relative 'lib/avro_decoder.rb'

def init
  return if $initialized

  $logger = NyplLogFormatter.new(STDOUT, level: ENV['LOG_LEVEL'] || 'info')
  $avro_decoders = {
    "Bib" => AvroDecoder.by_name('Bib')
  }

  $initialized = true
end

def handle_event(event:, context:)
  init

  event["Records"]
    .select { |record| record["eventSource"] == "aws:kinesis" }
    .each do |record|
      avro_data = record["kinesis"]["data"]

      # Determine what schema to use based on eventSourceARN:
      # ARN will end in a phrase like 'Bib-production', or 'BibBulk-production'
      schema_name = record["eventSourceARN"].split('/').last.sub(/(Bulk)?(-.*)?$/, '')
      raise "Unrecognized schema: #{schema_name}. Must be one of #{$avro_decoders.keys.join(', ')}" if ! $avro_decoders.keys.include? schema_name

      decoded = $avro_decoders[schema_name].decode avro_data
      $logger.debug "Decoded #{schema_name}", decoded

      uri = URI("http://docker.for.mac.localhost:8080/api/v0.1/bibs")

      Net::HTTP.post_form(uri, "data" => decoded.to_json)
    end
end
