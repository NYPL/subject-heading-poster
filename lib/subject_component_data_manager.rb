class SHEP
  class SubjectComponentDataManager
    attr_reader :subfield_data_mgrs

    def initialize(subfield_value_tags)
      @subfield_data_mgrs = subfield_value_tags.map { |sf| SubfieldDataManager.new(*sf) }
    end

    def tagged_label
      subfield_data_mgrs.map(&:value_tag).join(' / ')
    end
  end
end
