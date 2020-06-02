require 'spec_helper'

describe SHEP::BibDataManager do
  it "should return a tagged_label for 650 field" do
    data = {
      subfields: [["First component", "a"], ["Second component", "b"], ["Third component", "x"]],
      marc_field: '650',
    }
    bib_data_manager = SHEP::SubjectHeadingDataManager.new_from_data(data)

    expect(bib_data_manager.tagged_label).to eq("First component {a} // Second component {b} // Third component {x}")
  end

  it "should return a tagged_label for default field" do
    data = {
      subfields: [["First component", "a"], ["Second component", "b"], ["Third component", "x"]],
      marc_field: 'default',  # Not a valid value, but this method doesn't check
    }
    bib_data_manager = SHEP::SubjectHeadingDataManager.new_from_data(data)

    expect(bib_data_manager.tagged_label).to eq("First component {a} // Second component {b} // Third component {x}")
  end

  it "should return a tagged_label for 600 field" do
    data = {
      subfields: [['Mozart, Wolfgang Amadeus,', "a"], ["1756-1791", "d"]],
      marc_field: '600',
    }
    top_level_heading = SHEP::SubjectHeadingDataManager.new_from_data(data)

    expect(top_level_heading.tagged_label).to eq("Mozart, Wolfgang Amadeus, {a} / 1756-1791 {d}")

    data = {
      subfields: [['Mozart, Wolfgang Amadeus,', "a"], ["1756-1791", "d"], ['Apollo et Hyacinthus', 't']],
      marc_field: '600',
    }
    second_level_heading = SHEP::SubjectHeadingDataManager.new_from_data(data)

    expect(second_level_heading.tagged_label).to eq("Mozart, Wolfgang Amadeus, {a} / 1756-1791 {d} // Apollo et Hyacinthus {t}")

    data = {
      subfields: [
        ['Mozart, Wolfgang Amadeus,', "a"],
        ["1756-1791", "d"],
        ['Apollo et Hyacinthus', 't'],
        ['Appreciation', 'x'],
      ],
      marc_field: '600',
    }
    third_level_heading = SHEP::SubjectHeadingDataManager.new_from_data(data)

    expect(third_level_heading.tagged_label).to eq("Mozart, Wolfgang Amadeus, {a} / 1756-1791 {d} // Apollo et Hyacinthus {t} // Appreciation {x}")
  end

  it "tagged_label for 610 field" do
    data = {
      subfields: [["United States", "a"], ["Army", "b"], ["Cavalry, 7th", "b"], ["Company E", "b"]],
      marc_field: '610',
    }
    heading600 = SHEP::SubjectHeadingDataManager.new_from_data(data)

    expect(heading600.tagged_label).to eq "United States {a} // Army {b} // Cavalry, 7th {b} // Company E {b}"
  end

  it "tagged_label for 611 field" do
    data = {
      subfields: [["Biennale di Venezia", "a"], ["Padiglione italia", "e"], ["Exhibitions", "v"]],
      marc_field: '611',
    }
    heading611 = SHEP::SubjectHeadingDataManager.new_from_data(data)

    expect(heading611.tagged_label).to eq "Biennale di Venezia {a} // Padiglione italia {e} // Exhibitions {v}"
  end

  it "tagged_label for 630 field" do
    data = {
      subfields: [["Nutcracker (Choreographic work : Dolin after Ivanov)", "a"], ["Pas de deux", "p"]],
      marc_field: '630',
    }
    heading630 = SHEP::SubjectHeadingDataManager.new_from_data(data)

    expect(heading630.tagged_label).to eq "Nutcracker (Choreographic work : Dolin after Ivanov) {a} // Pas de deux {p}"
  end

  it "tagged_label with role component for 600 field" do
    data = {
      subfields: [["Hall, John T", "a"], ["(Composer)", "e"], ["Queen of the Moulin Rouge", "t"]],
      marc_field: '600',
    }
    heading600_with_role = SHEP::SubjectHeadingDataManager.new_from_data(data)

    expect(heading600_with_role.tagged_label).to eq "Hall, John T {a} // (Composer) {e} // Queen of the Moulin Rouge {t}"
  end

  it 'component_tag_groups_for_subfields should work for regular subfields' do
    subfields = [['subfield1', 'a'], ['subfield1', 'b']]
    expect(SHEP::SubjectHeadingDataManager._tag_groups subfields, 650).to eq %w[a b]
  end

  it 'component_tag_groups_for_subfields should subsume numbered fields' do
    subfields = [['subfield1', 'a'], ['metadata', '2'], ['subfield1', 'b']]
    expect(SHEP::SubjectHeadingDataManager._tag_groups subfields, '650').to eq %w[a2 b]
  end

  it 'component_tag_groups_for_subfields should composite fields for 600 subject' do
    subfields = [['name_subfield', 'a'], ['date_subfield', 'd'], ['another_subfield', 'x']]
    expect(SHEP::SubjectHeadingDataManager._tag_groups subfields, '600').to eq %w[ad x]
  end

  it '600 field regexes' do
    subfields = [
      ['name', 'a'], ['fuller', 'q'], ['title', 'c'], ['date', 'd'], ['misc', 'g'],
      ['another_subfield', 'x']
    ]
    expect(SHEP::SubjectHeadingDataManager._tag_groups subfields, '600').to eq %w[aqcdg x]

    subfields = [
      # Person
      ['name', 'a'], ['fuller', 'q'], ['title', 'c'], ['date', 'd'], ['misc', 'g'],
      # Work
      ['title', 't'], ['arranged_statement', 'o'], ['form_subhead', 'k'], ['language', 'l'], ['medium', 'm'],
      ['part', 'n'], ['work_date', 'f'], ['part_name', 'p'], ['key', 'r'], ['version', 's'],
      # Other
      ['another_subfield', 'x']
    ]
    expect(SHEP::SubjectHeadingDataManager._tag_groups subfields, '600').to eq %w[aqcdg toklmnfprs x]
  end

  it '610 field regexes' do
    subfields = [
      ['name', 'a'], ['title', 'c'], ['date', 'd'], ['misc', 'n'],
      ['another_subfield', 'x']
    ]
    expect(SHEP::SubjectHeadingDataManager._tag_groups subfields, '610').to eq %w[acdn x]

    subfields = [
      ['name', 'a'], ['title', 'c'], ['date', 'd'], ['misc', 'n'],
      ['sub-unit', 'b'],
      # Other
      ['another_subfield', 'x']
    ]
    expect(SHEP::SubjectHeadingDataManager._tag_groups subfields, '610').to eq %w[acdn b x]
  end

  it '611 field regexes' do
    subfields = [
      # Event
      ['name', 'a'], ['title', 'c'], ['date', 'd'], ['misc', 'n'],
      # Sub-category
      ['sub-unit', 'e'],
      # Title
      ['title', 't'], ['date of work', 'f'], ['form_subhead', 'k'], ['language', 'l'],
      ['part', 'n'], ['part_name', 'p'], ['version', 's'],
      # Random
      ['another_subfield', 'x']
    ]
    expect(SHEP::SubjectHeadingDataManager._tag_groups subfields, '611').to eq %w[acdn e tfklnps x]

    subfields = [
      # Event
      ['name', 'a'], ['title', 'c'], ['date', 'd'], ['misc', 'n'],
      # Title
      ['title', 't'], ['date of work', 'f'], ['form_subhead', 'k'], ['language', 'l'],
      ['part', 'n'], ['part_name', 'p'], ['version', 's'],
      # Sub-category
      ['sub-unit', 'e'],
      # Random
      ['another_subfield', 'x']
    ]
    expect(SHEP::SubjectHeadingDataManager._tag_groups subfields, '611').to eq %w[acdn tfklnps e x]
  end

  it '630 field regexes' do
    subfields = [
      # Work
      ['name', 'a'], ['date', 'd'],
      # Random
      ['another_subfield', 'x']
    ]
    expect(SHEP::SubjectHeadingDataManager._tag_groups subfields, '630').to eq %w[ad x]
  end

  it 'BibDataManager#process_subfield_data should drop any headings with blank content' do
    bib_processor = minimal_bib_data_manager

    subfield_data = [
      { 'content' => 'top level.', 'tag' => 'a' },
      { 'content' => '', 'tag' => 'b' },
      { 'content' => 'third level\.', 'tag' => 'x' },
    ]

    expect(bib_processor.process_subfield_data subfield_data).to eq([['top level', 'a'], ['third level', 'x']])

    subfield_data.push({ 'content' => '', 'tag' => 'x' })
    expect(bib_processor.process_subfield_data subfield_data).to eq([['top level', 'a'], ['third level', 'x']])

    subfield_data.unshift({ 'content' => '', 'tag' => 'a' })
    subfield_data.push({ 'content' => 'last subfield', 'tag' => 'x' })

    expect(bib_processor.process_subfield_data subfield_data).to eq([['top level', 'a'], ['third level', 'x'], ['last subfield', 'x']])
  end

  it 'extract_useful_var_fields should return subject_heading and published marc fields' do
    bib_processor = minimal_bib_data_manager

    marc_fields = [
      { 'marcTag' => '650' },
      { 'marcTag' => '008' },
      { 'marcTag' => '611' },
      { 'marcTag' => '001' },
      { 'marcTag' => '600' },
      { 'marcTag' => '260' },
      { 'marcTag' => '245' },
      { 'marcTag' => '999' },
      { 'marcTag' => '264' },
      { 'marcTag' => '600' },
      { 'marcTag' => '260' },
      { 'marcTag' => '008' },
    ]

    heading_fields, publication_year_fields = bib_processor.extract_useful_var_fields marc_fields

    expect(heading_fields).to eq [
      { 'marcTag' => '650' },
      { 'marcTag' => '611' },
      { 'marcTag' => '600' },
      { 'marcTag' => '600' },
    ]

    expect(publication_year_fields).to eq [
      { 'marcTag' => '008' },
      { 'marcTag' => '260' },
      { 'marcTag' => '264' },
      { 'marcTag' => '260' },
      { 'marcTag' => '008' },
    ]
  end

  it 'process_publication_year will find a date in 008 field' do
    processor = minimal_bib_data_manager
    marc_fields = [{
      'marcTag' => '008',
      'content' => 'abcdefs1973       ',
    }]

    expect(processor.process_publication_year marc_fields).to eq('1973')
  end

  it "process_publication_year will return nil if there's no date in expected position" do
    processor = minimal_bib_data_manager
    marc_fields = [{
      'marcTag' => '008',
      'content' => 'abcdefs    1973       ',
    }]

    expect(processor.process_publication_year marc_fields).to be_nil
  end

  it 'process_publication_year will find date in 260$t field' do
    processor = minimal_bib_data_manager
    marc_fields = [{
      'marcTag' => '260',
      'subfields' => [{
        'content' => '1978', 'tag' => 'c'
      }]
    }]

    expect(processor.process_publication_year marc_fields).to eq('1978')
  end

  it 'process_publication_year will find date in 264$t field' do
    processor = minimal_bib_data_manager
    marc_fields = [{
      'marcTag' => '264',
      'subfields' => [{
        'content' => '1983', 'tag' => 'c'
      }]
    }]

    expect(processor.process_publication_year marc_fields).to eq('1983')
  end

  it 'process_publication_year will ignore 260 without t subfield' do
    processor = minimal_bib_data_manager
    marc_fields = [{
      'marcTag' => '260',
      'subfields' => [{
        'content' => '1983', 'tag' => 's'
      }]
    }]

    expect(processor.process_publication_year marc_fields).to be_nil
  end

  it 'process_publication_year will ignore 264 without t subfield' do
    processor = minimal_bib_data_manager
    marc_fields = [{
      'marcTag' => '264',
      'subfields' => [{
        'content' => '1983', 'tag' => 's'
      }]
    }]

    expect(processor.process_publication_year marc_fields).to be_nil
  end

  it 'process_publication_year will prioritize a 008 year over a 260$t field' do
    processor = minimal_bib_data_manager
    marc_fields = [
      {
        'marcTag' => '008',
        'content' => 'abcdefs1973       ',
      },
      {
        'marcTag' => '260',
        'subfields' => [{
          'content' => '1983', 'tag' => 'c'
        }]
      }
    ]

    expect(processor.process_publication_year marc_fields).to eq('1973')
  end

  it 'process_publication_year will prioritize a 260$t year over a 264$t field' do
    processor = minimal_bib_data_manager
    marc_fields = [
      {
        'marcTag' => '260',
        'subfields' => [{
          'content' => '1978', 'tag' => 'c'
        }]
      },
      {
        'marcTag' => '264',
        'subfields' => [{
          'content' => '1983', 'tag' => 'c'
        }]
      }
    ]

    expect(processor.process_publication_year(marc_fields)).to eq '1978'
  end

  it 'process_publication_year will prioritize a less specific 008 year over a more specific 260$t field' do
    processor = minimal_bib_data_manager
    marc_fields = [
      {
        'marcTag' => '008',
        'content' => 'abcdefs1uuu       ',
      },
      {
        'marcTag' => '260',
        'subfields' => [{
          'content' => '1983', 'tag' => 'c'
        }]
      }
    ]

    expect(processor.process_publication_year(marc_fields)).to eq '1---'
  end

  it 'valid_year_match allows some non-numeric characters' do
    processor = minimal_bib_data_manager

    expect(processor.valid_year_match '197u').to be_truthy
    expect(processor.valid_year_match '197x').to be_truthy
    expect(processor.valid_year_match '197-').to be_truthy
    expect(processor.valid_year_match '19uu').to be_truthy
    expect(processor.valid_year_match '1uuu').to be_truthy
  end

  it 'valid_year_match finds first valid match' do
    processor = minimal_bib_data_manager

    expect(processor.valid_year_match('©197u')[0]).to eq '197u'
    expect(processor.valid_year_match('19731978')[0]).to eq '1973'
    expect(processor.valid_year_match('abcde1uuu1978')[0]).to eq '1uuu'
  end

  it 'valid_year_match returns nil for invalid sequences' do
    processor = minimal_bib_data_manager

    expect(processor.valid_year_match 'uuuu').to be_nil
    expect(processor.valid_year_match 'u197').to be_nil
    expect(processor.valid_year_match '    ').to be_nil
  end

  it 'rationalize_imprecise_year will change u and x characters (and only those) to - characters' do
    processor = minimal_bib_data_manager

    expect(processor.rationalize_imprecise_year('15uu')).to eq '15--'
    expect(processor.rationalize_imprecise_year('15xx')).to eq '15--'
    expect(processor.rationalize_imprecise_year('15--')).to eq '15--'

    # This shouldn't be converted
    expect(processor.rationalize_imprecise_year('15ss')).to eq '15ss'
  end

  it 'it should handle camelCase keys' do
    processor = minimal_bib_data_manager(snake_case: false)

    expect(processor.institution).to eq 'sierra_nypl'
  end
end
