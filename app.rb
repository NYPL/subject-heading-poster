require 'json'
require 'nypl_log_formatter'
require 'parallel'

require_relative 'lib/avro_decoder.rb'
require_relative 'lib/bib_data_manager.rb'
require_relative 'lib/platform_api_client.rb'

def init
  return if $initialized

  $logger = NyplLogFormatter.new(STDOUT, level: ENV['LOG_LEVEL'] || 'info')
  $platform_api = PlatformApiClient.new
  $avro_decoder = AvroDecoder.by_name('Bib')

  $initialized = true
end

def handle_event(event:, context:)
  init

  records_to_process = []
  # Parse records into array for parallel processing
  event["Records"]
    .select { |record| record["eventSource"] == "aws:kinesis" }
    .each do |record|
      records_to_process << record
    end

  # Process records in parallel
  record_results = Parallel.map(records_to_process, in_processes: ENV['PARALLEL_PROCESSES'].to_i) { |record| process_record(record) }
end

def process_record record
  decoded_record = parse_record(record)

  unless decoded_record && should_process?(decoded_record)
    return decoded_record ? [decoded_record['id'], 'SKIPPING'] : [nil, 'ERROR']
  end

  return store_record(decoded_record)
end

def parse_record record
  begin
    avro_data = record["kinesis"]["data"]
  rescue *[KeyError, NoMethodError] => e
    $logger.error "Missing field in Kinesis message, unable to process #{e.message}"
    return nil 
  end

  begin
    decoded = $avro_decoder.decode avro_data
    $logger.debug "Decoded bib", decoded
  rescue AvroError => e
    $logger.error "Record failed Avro validation for reason: #{e.message}"
    return nil
  end

  return decoded
end

def store_record decoded
  # make POST request to SHEP API
  uri = URI(ENV['SHEP_API_BIBS_ENDPOINT'])

  resp = Net::HTTP.post_form(uri, "data" => decoded.to_json)
  if resp.code.to_i > 400
    message = JSON.parse(resp.body)["message"]
    log_message = "Bib #{decoded['nyplSource']} #{decoded['id']} not processed by Subject Heading (SHEP) API"
    log_message += "; message: #{message}" if message
    $logger.error log_message
    return [decoded['id'], 'ERROR']
  end

  $logger.debug "Response", { "resp": JSON.parse(resp.body)}

  $logger.info "Bib #{decoded['nyplSource']} #{decoded['id']} successfully processed by Subject Heading (SHEP) API" if resp.code.to_i == 201
  return [decoded['id'], 'SUCCESS']
end

def should_process? data
  is_research?(data) && have_subject_headings_changed?(data)
end

def is_research? data
  nypl_source = data['nyplSource']
  bib_id = data['id']

  begin
    research_status = $platform_api.get("bibs/#{nypl_source}/#{bib_id}/is-research")
  rescue Exception => e
    $logger.warn "Unexpected Error encountered #{e.message}"
    return false
  end
  
  unless research_status["isResearch"]
    $logger.debug "Circulating bib #{bib_id}, will not process"
    return false
  end

  return true
end

def have_subject_headings_changed? data
  # discovery id can come from BibDataManager
  begin
    bib_data = SHEP::BibDataManager.new(data)
  rescue SHEP::BibDataManagerError => e
    $logger.error "Unable to process record due to: #{e.message}"
    return false
  end

  incoming_tagged_subject_headings = bib_data.heading_data_mgrs.map(&:tagged_label).sort

  discovery_id = bib_data.discovery_id

  # make GET request to SHEP API Bib#tagged_subject_headings endpoint
  uri = URI("#{ENV['SHEP_API_BIBS_ENDPOINT']}#{discovery_id}/tagged_subject_headings")
  resp = Net::HTTP.get_response(uri)

  if resp.code == "404"
    $logger.info "Record Not Found and subject headings length #{incoming_tagged_subject_headings.length}"
    return incoming_tagged_subject_headings.length > 0
  end

  unless resp.code == "200"
    $logger.warn "Unexpected result from SHEP API 'Bib#tagged_subject_headings' endpoint for bib #{discovery_id}. Will not process. Message: #{resp.message}"
    return false
  end

  preexisting_tagged_subject_headings = JSON.parse(resp.body)["tagged_subject_headings"].sort;

  $logger.info "incoming_tagged_subject_headings: #{incoming_tagged_subject_headings}, preexisting_tagged_subject_headings: #{preexisting_tagged_subject_headings}"

  if preexisting_tagged_subject_headings.sort == incoming_tagged_subject_headings.sort
    $logger.info "No change to subject headings for bib #{discovery_id}, will not process"
    return false
  end

  return true
end
