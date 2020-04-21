require 'json'
require 'nypl_log_formatter'

# require the `is_research` layer Bib class
require '/opt/is-research-layer/lib/bib'

require_relative 'lib/avro_decoder.rb'

def init
  return if $initialized

  $logger = NyplLogFormatter.new(STDOUT, level: ENV['LOG_LEVEL'] || 'info')
  $platform_api = PlatformApiClient.new
  $avro_decoder = AvroDecoder.by_name('Bib')
  $nypl_core = NyplCore.new

  $initialized = true
end

def handle_event(event:, context:)
  init

  event["Records"]
    .select { |record| record["eventSource"] == "aws:kinesis" }
    .each do |record|
      avro_data = record["kinesis"]["data"]

      decoded = $avro_decoder.decode avro_data
      $logger.debug "Decoded bib", decoded

      bib = Bib.new(decoded['nyplSource'], decoded['id'])

      is_research = bib.is_research?

      return $logger.debug "Circulating bib #{decoded['id']}, will not process" unless is_research

      uri = URI(ENV['SHEP_API_BIBS_ENDPOINT'])

      resp = Net::HTTP.post_form(uri, "data" => decoded.to_json)

      $logger.error "Bib #{decoded['nyplSource']} #{decoded['id']} not processed by Subject Heading (SHEP) API" if resp.code.to_i > 400
    end
end