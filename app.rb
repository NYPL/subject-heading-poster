require 'json'
require 'nypl_log_formatter'

# require the `is_research` layer Bib class
require '/opt/is-research-layer/lib/bib'

require_relative 'lib/avro_decoder.rb'
require_relative 'lib/utils.rb'

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

      puts decoded

      nypl_source = decoded['nyplSource']
      bib_id = decoded['id']

      return $logger.error "nyplSource #{nypl_source} not recognized" unless nypl_sources.include?(nypl_source)

      bib = Bib.new(nypl_source, bib_id)

      begin
        is_research = bib.is_research?
      rescue DeletedError => e
        return $logger.debug "Deleted bib #{bib_id}, will not process"
      rescue => e
        return $logger.warn "#{e.class}: #{e.message}; bib #{nypl_source} #{bib_id}"
      end

      return $logger.debug "Circulating bib #{bib_id}, will not process" unless is_research

      discovery_id = discovery_id(nypl_source, bib_id)
      # make GET request to SHEP API Bib#tagged_subject_headings endpoint
      uri = URI("#{ENV['SHEP_API_BIBS_ENDPOINT']}#{discovery_id}/tagged_subject_headings")
      resp = Net::HTTP.get_response(uri)

      preexisting_tagged_subject_headings = JSON.parse(resp.body)["tagged_subject_headings"] if resp.code == "200"

      puts preexisting_tagged_subject_headings.class

      incoming_tagged_subject_headings = parse_tagged_subject_headings(decoded)

      return

      # make POST request to SHEP API
      uri = URI(ENV['SHEP_API_BIBS_ENDPOINT'])

      resp = Net::HTTP.post_form(uri, "data" => decoded.to_json)

      if resp.code.to_i > 400
        message = JSON.parse(resp.body)["message"]
        log_message = "Bib #{decoded['nyplSource']} #{decoded['id']} not processed by Subject Heading (SHEP) API"
        log_message += "; message: #{message}" if message
        $logger.error log_message
      end

      $logger.info "Bib #{decoded['nyplSource']} #{decoded['id']} successfully processed by Subject Heading (SHEP) API" if resp.code.to_i == 201
    end
end
