require 'spec_helper'

describe Bib do
  test_bibs = [
    {
      bib: Bib.new("recap-pul", "7843570"), # partner record
      result: true
    },
    {
      bib: Bib.new("sierra-nypl", "17906651"), # has an item that is research
      result: true
    },
    {
      bib: Bib.new("sierra-nypl", "10036259"), # mixed bib that calls Bib#is_mixed_bib?
      result: true
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
    .to_return(status: 200, body: File.read("./spec/fixtures/by_sierra_location.json"))

    stub_request(:post, "#{ENV['NYPL_OAUTH_URL']}oauth/token").to_return(status: 200, body: '{ "access_token": "fake-access-token" }')

    test_bibs.each do |test_bib|
      stub_request(:get,
        "#{ENV['PLATFORM_API_BASE_URL']}bibs/#{test_bib[:bib].nypl_source}/#{test_bib[:bib].id}/items").to_return(status: 200, body: File.read("./spec/fixtures/bib_items_#{test_bib[:bib].id}.json")
      )
    end

    stub_request(:get,
      "#{ENV['PLATFORM_API_BASE_URL']}bibs/recap-pul/66666/items").to_return(status: 404, body: File.read("./spec/fixtures/sierra_404.json")
    )

    stub_request(:get,
      "#{ENV['PLATFORM_API_BASE_URL']}bibs/recap-pul/66666").to_return(status: 200, body: File.read("./spec/fixtures/bib_66666.json")
    )

    stub_request(:get,
      "#{ENV['PLATFORM_API_BASE_URL']}bibs/sierra-nypl/19060447/items").to_return(status: 404, body: File.read("./spec/fixtures/sierra_404.json")
    )

    stub_request(:get,
      "#{ENV['PLATFORM_API_BASE_URL']}bibs/sierra-nypl/19060447").to_return(status: 200, body: File.read("./spec/fixtures/bib_19060447.json")
    )
  end

  describe "is_research?" do
    it "should declare partner record as research" do
      test_bib = test_bibs[0]
      expect(test_bib[:bib].is_research?).to eq(test_bib[:result])
    end

    it "should declare a bib with 0 items as research" do
      test_bib = test_bibs[1]
      expect(test_bib[:bib].is_research?).to eq(test_bib[:result])
    end

    it "should declare a bib with at least one research item as research" do
      test_bib = Bib.new('recap-pul', '66666')
      expect(test_bib.is_research?).to eq(true)
    end

    it "should throw DeletedError for a deleted bib record" do
      test_bib = Bib.new('sierra-nypl', '19060447')
      expect { test_bib.is_research? }.to raise_error(DeletedError)
    end

    it "should declare a mixed bib as research" do
      test_bib = test_bibs[2]
      expect(test_bib[:bib].is_research?).to eq(test_bib[:result])
    end
  end
end
