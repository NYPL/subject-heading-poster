require 'json'
require 'nypl_log_formatter'

# require the `is_research` layer Bib class
require '/opt/is-research-layer/lib/bib'

require_relative 'lib/avro_decoder.rb'
require_relative 'lib/bib_data_manager.rb'

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

      return unless should_process? decoded
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

def should_process? data
  is_research?(data) && have_subject_headings_changed?(data)
end

def is_research? data
  nypl_source = data['nyplSource']
  bib_id = data['id']

  bib = Bib.new(nypl_source, bib_id)

  begin
    is_research = bib.is_research?
  rescue DeletedError => e
    $logger.debug "Deleted bib #{bib_id}, will not process"
    return false
  rescue => e
    $logger.warn "#{e.class}: #{e.message}; bib #{nypl_source} #{bib_id}"
    return false
  end

  unless is_research
    $logger.debug "Circulating bib #{bib_id}, will not process"
    return false
  end

  return true
end

def have_subject_headings_changed? data
  # discovery id can come from BibDataManager
  bib_data = SHEP::BibDataManager.new(data)
  incoming_tagged_subject_headings = bib_data.heading_data_mgrs.map(&:tagged_label).sort

  discovery_id = bib_data.discovery_id

  # make GET request to SHEP API Bib#tagged_subject_headings endpoint
  uri = URI("#{ENV['SHEP_API_BIBS_ENDPOINT']}#{discovery_id}/tagged_subject_headings")
  resp = Net::HTTP.get_response(uri)

  not_found = resp.code == "404"

  return not_found && incoming_tagged_subject_headings.length > 0 if not_found 

  unless resp.code == "200"
    $logger.warn "Unexpected result from SHEP API 'Bib#tagged_subject_headings' endpoint for bib #{discovery_id}. Will not process. Message: #{resp.message}"
    return false
  end

  preexisting_tagged_subject_headings = JSON.parse(resp.body)["tagged_subject_headings"].sort;

  $logger.debug "incoming_tagged_subject_headings: #{incoming_tagged_subject_headings}, preexisting_tagged_subject_headings: #{preexisting_tagged_subject_headings}"

  if preexisting_tagged_subject_headings.sort == incoming_tagged_subject_headings.sort
    $logger.info "No change to subject headings for bib #{discovery_id}, will not process"
    return false
  end

  return true
end
