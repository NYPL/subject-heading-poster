require 'open-uri'

class NyplCore
  def initialize
    @mappings = {}
  end

  def by_sierra_location
    by_mapping('by_sierra_location.json')
  end

  def by_catalog_item_type
    by_mapping('by_catalog_item_type.json')
  end

  private
  def by_mapping (mapping_file)
    @mappings[mapping_file] = JSON.parse(open(ENV['NYPL_CORE_S3_BASE_URL'] + mapping_file).read) if @mappings[mapping_file].nil?
    @mappings[mapping_file]
  end
end
