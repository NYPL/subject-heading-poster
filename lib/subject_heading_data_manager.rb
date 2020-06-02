class SHEP
  class SubjectHeadingDataManager
    attr_reader :component_data_mgrs

    composite_rules = {
      '600' => %r{(?:^a[cdgq0-9]*)|(?:t[fklmnoprs0-9]*)|(?:[a-z][0-9]*)},
      '610' => %r{(?:^a[^b]?[cdn0-9]*)|(?:b[0-9]*)|(?:[a-z][0-9]*)},
      '611' => %r{(?:^a[cdn0-9]*)|(?:t[fklnps0-9]*)|(?:[a-z][0-9]*)},
      '630' => %r{(?:^a[d0-9]*)|(?:[a-z][0-9]*)},
    }
    COMPONENT_RULES = Hash.new(%r{[a-z](?:[0-9]*)}).merge(composite_rules)

    def self.new_from_data(heading_data)
      marc_field = heading_data[:marc_field]
      subfields = heading_data[:subfields]
      secondary = heading_data[:secondary]

      these_component_ranges = _component_ranges(subfields, marc_field)
      components = these_component_ranges.map { |range| SubjectComponentDataManager.new(subfields[*range]) }

      SubjectHeadingDataManager.new(components, marc_field, secondary)
    end

    # Get subfields from components
    def self._tag_groups(subfields, marc_field)
      subfields
      .map(&:last)
      .join
      .scan(COMPONENT_RULES[marc_field.to_s])
      .to_a
    end

    def self._component_ranges(subfields, marc_field)
      component_lengths = _tag_groups(subfields, marc_field).map(&:length)

      component_lengths.inject([]) do |ranges, length|
        last = ranges.last

        start = last.nil? ? 0 : last[0] + last[1]

        ranges << [start, length]
      end
    end

    def initialize(components, marc_field, secondary)
      @component_data_mgrs = components
      @marc_field = marc_field
      @secondary = secondary

      @parent = @component_data_mgrs.length == 1 ?
      nil :
      SubjectHeadingDataManager.new(@component_data_mgrs[0..-2], @marc_field, @secondary)
    end

    def tagged_label
      component_data_mgrs.map(&:tagged_label).join(' // ')
    end
  end
end
