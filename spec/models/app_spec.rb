require 'spec_helper'

describe "handler" do
  describe "#init" do
    before(:each) {
      allow(AvroDecoder).to receive(:by_name).with("Bib")
    }
    it "should set initialized to true" do
      expect(AvroDecoder).to receive(:by_name).with("Bib")
      init
      expect($initialized).to eq(true)
    end
  end

  describe "#handle_event" do
    it "should process all events passed in" do
      test_records = [{"eventSource" => "aws:kinesis", :rec => 1}, {"eventSource" => "aws:kinesis", :rec => 2}]
      allow(Parallel).to receive(:map).with(test_records, in_processes: 2).and_return([true, true])
  
      records_status = handle_event(event: {"Records" => test_records}, context: {})
      expect(records_status).to eq([true, true])
    end

    it "should do nothing if no records are present in the event" do
      test_records = []
      records_status = handle_event(event: {"Records" => test_records}, context: {})
      expect(records_status).to eq([])
    end
  end

  describe "#process_record" do
    before(:each) {
      @record = {"id" => 1}
    }

    it "should invoke store_record if record is processable" do
      allow(self).to receive(:parse_record).and_return(@record)
      allow(self).to receive(:is_research?).with(@record).and_return(true)
      allow(self).to receive(:store_record).with(@record).and_return(true)

      result = process_record(@record)

      expect(result).to eq(true)
    end

    it "should return SKIPPING STATUS if is_research? is false" do
      allow(self).to receive(:parse_record).and_return(@record)
      allow(self).to receive(:is_research?).with(@record).and_return(false)

      result = process_record(@record)

      expect(result).to eq([1, 'SKIPPING'])
    end

    it "should return ERROR if decoded_record is nill" do
      allow(self).to receive(:parse_record).and_return(nil)

      result = process_record(@record)

      expect(result).to eq([nil, 'ERROR'])
    end
  end
  
  describe "#parse_record" do
    before(:each) {
      $avro_decoder = double()
      allow($avro_decoder).to receive(:decode)
    }

    it "should return an object if avro decoding succeeds" do
      valid_record = {
        "kinesis" => {
          "data" => {"encoded" => {:id => 1, :title => "testing"}}
        }
      }

      expect($avro_decoder).to receive(:decode).and_return(valid_record["kinesis"]["data"]["encoded"])

      decoded_record = parse_record(valid_record)

      expect(decoded_record[:id]).to eq(1)
      expect(decoded_record[:title]).to eq("testing")
    end

    it "should raise an error if avro fails to decode a record" do
      valid_record = {
        "kinesis" => {
          "data" => {"encoded" => {:id => 1, :title => "testing"}}
        }
      }

      expect($avro_decoder).to receive(:decode).and_raise(AvroError.new("testing"))

      decoded_record = parse_record(valid_record)

      expect(decoded_record).to eq(nil)
    end

    it "should raise an error if the document is malformed" do
      invalid_record = {}
      decoded_record = parse_record(invalid_record)
      expect(decoded_record).to eq(nil)
    end
  end

  describe "#store_record" do
    before(:each) { allow(Net::HTTP).to receive(:post_form) }

    it "should return success if SHEP API returns 201" do
      resp = double('response', code: '201', body: JSON.dump({'message' => 'success'}))
      expect(Net::HTTP).to receive(:post_form).and_return(resp)

      output = store_record({'id' => 1, 'nypl-source' => 'nypl-test'})
      expect(output).to eq([1, 'SUCCESS'])
    end

    it 'should return not-modified if SHEP API returns 304' do
      resp = double('response', code:  '304', body: nil)
      expect(Net::HTTP).to receive(:post_form).and_return(resp)

      output = store_record({'id' => 1, 'nypl-source' => 'nypl-test'})
      expect(output).to eq([1, 'NOT MODIFIED'])
    end
 
    it 'should return unexpected response if SHEP API returns 200 (which the API should not do)' do
      resp = double('response', code:  '200', body: JSON.dump({'message' => 'success'}))
      expect(Net::HTTP).to receive(:post_form).and_return(resp)

      output = store_record({'id' => 1, 'nypl-source' => 'nypl-test'})
      expect(output).to eq([1, 'UNEXPECTED RESPONSE'])
    end

    it "should return error if SHEP API returns 400+" do
      resp = double("response", :code => '403', :body => JSON.dump({'message' => 'error'}))
      expect(Net::HTTP).to receive(:post_form).and_return(resp)

      output = store_record({'id' => 1, 'nypl-source' => 'nypl-test'})
      expect(output).to eq([1, 'ERROR'])
    end
  end

  describe "#is_research?" do
    before(:each) {
      allow($platform_api).to receive(:get)
    }

    it "should return true if there is a 911 field with subfield tag of a and a value of RL" do
      json_varfields = JSON.dump([{
        'marcTag' => '911',
        'subfields' => [{ 'content' => 'RL', 'tag' => 'a' }]
      }])

      expect(is_research?({'varFields' => json_varfields})).to eq(true)
    end

    it "should return false if there is a 911 field with subfield tag of a and a value of BL" do
      json_varfields = JSON.dump([{
        'marcTag' => '911',
        'subfields' => [{ 'content' => 'BL', 'tag' => 'a' }]
      }])

      expect(is_research?({'varFields' => json_varfields})).to eq(false)
    end

    it "should return false if there is a 911 field with subfield tag of a and a value of anything else" do
      json_varfields = JSON.dump([{
        'marcTag' => '911',
        'subfields' => [{ 'content' => 'RLOTF', 'tag' => 'a' }]
      }])

      expect(is_research?({'varFields' => json_varfields})).to eq(false)
    end

    # It's only the 911|a Marc field that we know is used for this. A 911 field with anything else could be 
    #   for a different purpose so it tells us nothing about the research status of this Bib
    it "should fallback to API if there is a 911 field with subfield tag other than a" do
      json_varfields = JSON.dump([{
        'marcTag' => '911',
        'subfields' => [{ 'content' => 'RL', 'tag' => 'z' }]
      }])

      expect($platform_api).to receive(:get).with('bibs/test-nypl/1/is-research').and_return({"isResearch" => true})
      expect(is_research?({'id' => '1', 'nyplSource' => 'test-nypl', 'varFields' => json_varfields})).to eq(true)
    end

    it "should take the first 911|a field if there are multiples (RL first test)" do
      json_varfields = JSON.dump([
        {
          'marcTag' => '911',
          'subfields' => [{ 'content' => 'RL', 'tag' => 'a' }]
        },
        {
          'marcTag' => '911',
          'subfields' => [{ 'content' => 'BL', 'tag' => 'a' }]
        }
      ])

      expect(is_research?({'varFields' => json_varfields})).to eq(true)
    end

    it "should take the first 911|a field if there are multiples (BL first test)" do
      json_varfields = JSON.dump([
        {
          'marcTag' => '911',
          'subfields' => [{ 'content' => 'BL', 'tag' => 'a' }]
        },
        {
          'marcTag' => '911',
          'subfields' => [{ 'content' => 'RL', 'tag' => 'a' }]
        }
      ])

      expect(is_research?({'varFields' => json_varfields})).to eq(false)
    end

    it "should ignore 911 without an 'a' subfield, processing a later one with an 'a' subfield" do
      json_varfields = JSON.dump([
        {
          'marcTag' => '911',
          'subfields' => [{ 'content' => 'BL', 'tag' => 'b' }]
        },
        {
          'marcTag' => '911',
          'subfields' => [{ 'content' => 'RL', 'tag' => 'a' }]
        }
      ])

      expect(is_research?({'varFields' => json_varfields})).to eq(true)
    end

    it "should return true if API response is true" do
      expect($platform_api).to receive(:get).with('bibs/test-nypl/1/is-research').and_return({"isResearch" => true})
      expect(is_research?({'nyplSource' => 'test-nypl', 'id' => '1'})).to eq(true)
    end

    it "should return false if API response is false" do
      expect($platform_api).to receive(:get).with('bibs/test-nypl/1/is-research').and_return({"isResearch" => false})
      expect(is_research?({'nyplSource' => 'test-nypl', 'id' => '1'})).to eq(false)
    end

    it "should return false if API request receives an error" do
      expect($platform_api).to receive(:get).with('bibs/test-nypl/1/is-research').and_raise(Exception.new)
      expect(is_research?({'nyplSource' => 'test-nypl', 'id' => '1'})).to eq(false)
    end


  end
end
