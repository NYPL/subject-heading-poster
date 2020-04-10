require 'spec_helper'
require 'webmock/rspec'

describe Item do
  test_items = [
    {
      item: Item.new("sierra-nypl", "37314241"),  # item type and location are branch
      result: false
    },
    {
      item: Item.new("recap-pul", "6739525"), # partner item
      result: true
    },
    {
      item: Item.new("sierra-nypl", "10002559"), # collectionType is only 'Research'
      result: true
    },
    {
      item: Item.new("sierra-nypl", "26085395"), # collectionType is both 'Research' and 'Branch'; item collectionType 'Research'
      result: true
    },
    {
      item: Item.new("sierra-nypl", "F17903918"), # fake record to reflect collectionType is both and item type is both
      result: true
    },
    {
      item: Item.new("sierra-nypl", "F16398857"), # fake record to reflect collectionType is both and item type is 'Branch'
      result: false
    },
    {
      item: Item.new("sierra-nypl", "36387834"), # real ID but unknown location_code and item_type_code
      result: false
    }
  ]

  before(:each) do
    $platform_api = PlatformApiClient.new
    $nypl_core = NyplCore.new

    KmsClient.aws_kms_client.stub_responses(:decrypt, -> (context) {
      # "Decrypt" by subbing "encrypted" with "decrypted" in string:
      { plaintext: context.params[:ciphertext_blob].gsub('encrypted', 'decrypted') }
    })

    $logger = NyplLogFormatter.new(STDOUT, level: ENV['LOG_LEVEL'] || 'info')

    stub_request(:get, ENV['NYPL_CORE_S3_BASE_URL'] + "by_catalog_item_type.json")
    .to_return(status: 200, body: File.read("./spec/fixtures/by_catalog_item_type.json"))

    stub_request(:get, ENV['NYPL_CORE_S3_BASE_URL'] + "by_sierra_location.json")
    .to_return(status: 200, body: File.read("./spec/fixtures/by_sierra_location.json"), headers: {})

    stub_request(:post, "#{ENV['NYPL_OAUTH_URL']}oauth/token").to_return(status: 200, body: '{ "access_token": "fake-access-token" }')

    test_items.each do |test_item|
      stub_request(:get,
        "#{ENV['PLATFORM_API_BASE_URL']}items/#{test_item[:item].nypl_source}/#{test_item[:item].id}").to_return(status: 200, body: File.read("./spec/fixtures/item_#{test_item[:item].id}.json")
      )
    end
  end

  describe "#is_research?" do
    it "should declare partner items as research" do
      test_item = test_items[1]
      expect(test_item[:item].is_research?).to eq(test_item[:result])
    end

    it "should declare branch items as not research" do
      test_item = test_items[0]
      expect(test_item[:item].is_research?).to eq(test_item[:result])
    end

    it "should declare an item whose location has collectionType 'Research' (only) to be research" do
      test_item = test_items[2]
      expect(test_item[:item].is_research?).to eq(test_item[:result])
    end

    it "should declare an item whose location has collectionType 'Research' and 'Branch' and item type with collectionType 'Research' as research" do
      test_item = test_items[3]
      expect(test_item[:item].is_research?).to eq(test_item[:result])
    end

    it "should declare an item whose location has collectionType 'Research' and 'Branch' and item type with collectionType 'Research' and 'Branch' as research" do
      test_item = test_items[4]
      expect(test_item[:item].is_research?).to eq(test_item[:result])
    end

    it "should declare an item whose location has collectionType 'Research' and 'Branch' and item type with collectionType 'Branch' as not research" do
      test_item = test_items[5]
      expect(test_item[:item].is_research?).to eq(test_item[:result])
    end

    it "should throw DataError for unknown item_type_code and/or location_code" do
      test_item = test_items[6]
      expect { test_item[:item].is_research? }.to raise_error(DataError)
    end
  end
end
