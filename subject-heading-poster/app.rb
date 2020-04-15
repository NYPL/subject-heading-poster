require 'json'
require 'nypl_log_formatter'

# require the `is_research` layer Bib class
require '/opt/is-research-layer/lib/bib'

require_relative 'lib/avro_decoder.rb'

def init
  return if $initialized

  $logger = NyplLogFormatter.new(STDOUT, level: ENV['LOG_LEVEL'] || 'info')
  $avro_decoder = AvroDecoder.bib
  $nypl_core = NyplCore.new
  $platform_api = PlatformApiClient.new

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

      return unless is_research

      uri = URI("http://docker.for.mac.localhost:8080/api/v0.1/bibs")

      resp = Net::HTTP.post_form(uri, "data" => decoded.to_json)

      $logger.info "#{resp.code} #{resp.body}"
    end
end
