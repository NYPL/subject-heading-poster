require 'json'
require 'nypl_log_formatter'

require_relative 'marc_record'
require_relative 'errors'
require_relative 'item'

class Bib < MarcRecord
  @@mixed_bib_ids = nil

  def is_research?
    begin
      items = get_platform_api_data items_path
      result = is_partner? || first_item_is_research?(items) || is_mixed_bib?
    rescue NotFoundError => e
      bib = get_platform_api_data bib_path
      raise DeletedError if bib["deleted"]
      result = !!bib
    end

    $logger.debug "Evaluating is-research for bib #{nypl_source} #{id}: #{result}", @log_data

    result
  end

  private
  def is_mixed_bib?
    if @@mixed_bib_ids.nil?
      @@mixed_bib_ids = File.read('data/mixed-bibs.csv')
      .split("\n")
      .map { |bnum| bnum.strip.sub(/^b/, '').chop }

      $logger.debug "Loaded #{@@mixed_bib_ids.size} mixed bib ids"
    end

    is_mixed_bib = @@mixed_bib_ids.include? id
    $logger.debug "Determined is_mixed_bib=#{is_mixed_bib} for #{id}"

    is_mixed_bib
  end

  def first_item_is_research?(items)
    item_record = items[0]
    item = Item.new(item_record["nyplSource"], item_record["id"])
    result = item.is_research?(item_record)

    @log_data[:has_at_least_one_research_item?] = result

    result
  end

  def bib_path
    "bibs/" + @nypl_source + "/" + @id
  end

  def items_path
    bib_path + "/items"
  end
end
