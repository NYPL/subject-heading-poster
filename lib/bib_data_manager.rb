require_relative 'subject_heading_data_manager'
require_relative 'subject_component_data_manager'
require_relative 'subfield_data_manager'

class SHEP
  class BibDataManager
    attr_reader :institution, :bib_id, :heading_data_mgrs, :discovery_id

    BIB_ID_PREFIXES_BY_INSTITUTION = Hash.new('b').merge({
      'sierra-nypl' => 'b',
      'recap-cul' => 'cb',
      'recap-pul' => 'pb',
      }).freeze

      MAIN_PUBLICATION_YEAR_MARC_TAG = '008'.freeze
      SECONDARY_PUBLICATION_YEAR_MARC_TAGS = {
        '260' => 'c',
        '264' => 'c',
      }.freeze
      # NB, SECONDARY_PUBLICATION_YEAR_MARC_TAGS.keys preserves the order above
      PUBLICATION_YEAR_MARC_TAGS = [MAIN_PUBLICATION_YEAR_MARC_TAG] + SECONDARY_PUBLICATION_YEAR_MARC_TAGS.keys

      VALID_YEAR_VALUE_RX = %r{\d[\dux-]{3}}.freeze

      # according to https://neo4j.com/docs/operations-manual/current/performance/index-configuration/schema-indexes/index-key-size-calcuations/
      MAX_STRING_LENGTH = 2018  # Half Neo4j's max index length as encoded label is also indexed & has two bytes per char

      def initialize(bib_marc)
        @bib_id = bib_marc['id']
        @institution = bib_marc['nyplSource'] || bib_marc['nypl_source']

        @discovery_id = BIB_ID_PREFIXES_BY_INSTITUTION[institution] + bib_id

        if bib_marc['title'].nil?
          error_message = "No title on bib #{bib_marc['id']}, source #{@institution}"
          raise BibDataManagerError, error_message
        end
        @title = bib_marc['title'].sub(%r{\\$}, '')  # escaping terminating backslash

        begin
          @language_code = bib_marc['lang']['code']
          bib_marc_var_fields = bib_marc['varFields'] || bib_marc['var_fields']
          var_fields = bib_marc_var_fields.class == String ? JSON.parse(bib_marc_var_fields) : bib_marc_var_fields
        rescue StandardError => e
          raise BibDataManagerError, "Problem parsing JSON for #{discovery_id}: #{e.message}"
        end

        headings_fields, publication_year_fields = extract_useful_var_fields(var_fields)

        @publication_year = process_publication_year publication_year_fields

        @heading_data_mgrs = headings_data(headings_fields).map do |heading_data|
          next unless subject_heading_length_ok? heading_data[:subfields]

          SubjectHeadingDataManager.new_from_data(heading_data)
        end.compact
      end

      def extract_useful_var_fields(var_fields)
        useful = var_fields.inject({ headings: [], published_date: [] }) do |useful_fields, field|
          next useful_fields unless field['marcTag']

          useful_fields[:headings] << field if field['marcTag'].match %r{^(6\d\d)$}
          useful_fields[:published_date] << field if PUBLICATION_YEAR_MARC_TAGS.include? field['marcTag']

          useful_fields
        end

        useful.values_at(:headings, :published_date)
      end

      def headings_data(var_fields)
        var_fields.inject([]) do |data, field|
          next data unless field['marcTag']

          matches = field['marcTag'].match %r{^(6\d\d)$}
          next data unless matches

          marc_field = matches[0].to_i

          subfield_value_tags = process_subfield_data(field['subfields'])

          # Only want to bother with regular subject headings, with an 'a' subfield tag in first position
          next data if subfield_value_tags.empty? || subfield_value_tags[0][1] != 'a'

          data.push(
            marc_field: marc_field,
            secondary: field['ind1'].to_i == 2,
            subfields: subfield_value_tags
          )
        end
      end

      def process_subfield_data(subfield_data)
        subfield_data.map do |sf|
          # Remove trailing periods _and_ backslashes, and convert erroneous ' -- ' to something innocuous
          value = sf['content'].strip.sub(%r{[.\\]+$}, '').sub(' -- ', ' __ ')

          # Reject any blank subfields
          next if value.empty?

          [value, sf['tag']]
        end.compact
      end

      # rubocop:disable Layout/EmptyLinesAroundBlockBody -- So many loops & conditionals, need a bit of space
      def process_publication_year(marc_fields)
        # See https://www.loc.gov/marc/bibliographic/bd008.html &
        #   https://www.loc.gov/marc/bibliographic/bd008a.html  for details

        PUBLICATION_YEAR_MARC_TAGS.each do |wanted_marc_tag|

          # Could end up going through marc_fields once for each possible marc tag
          marc_fields.each do |f|
            if f['marcTag'] == wanted_marc_tag

              if f['marcTag'] == MAIN_PUBLICATION_YEAR_MARC_TAG

                possible_year = f['content'][7..10]
                return rationalize_imprecise_year possible_year if possible_year && valid_year_match(possible_year)

              else

                possible_year = find_publication_year_from_secondary_field(f, f['marcTag'])
                return rationalize_imprecise_year possible_year unless possible_year.nil?

              end
            end
          end
        end

        nil
      end

      def find_publication_year_from_secondary_field(field, this_marc_tag)
        pub_year_subfield_tag = SECONDARY_PUBLICATION_YEAR_MARC_TAGS.to_h[this_marc_tag]

        field['subfields'].each do |sf|
          next unless sf['tag'] == pub_year_subfield_tag

          match_data = valid_year_match sf['content']
          return match_data[0] if match_data
        end

        nil
      end

      def valid_year_match(possible)
        possible.match(VALID_YEAR_VALUE_RX)
      end

      def rationalize_imprecise_year(year)
        year.tr('xu', '-')
      end

      def subject_heading_length_ok?(subfields)
        # if tagged label < max, all derived fields should be too
        tagged_label_max_length = subfields.inject(0) do |length, subfield|
          length + subfield[0].bytesize + 8  # 8 for the ' {a} // ' type delimiters
        end
        tagged_label_max_length <= MAX_STRING_LENGTH
      end
    end
end
