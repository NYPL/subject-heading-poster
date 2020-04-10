require 'spec_helper'
require 'webmock/rspec'

describe PlatformApiClient do
  before(:each) do
    KmsClient.aws_kms_client.stub_responses(:decrypt, -> (context) {
      # "Decrypt" by subbing "encrypted" with "decrypted" in string:
      { plaintext: context.params[:ciphertext_blob].gsub('encrypted', 'decrypted') }
    })

    $logger = NyplLogFormatter.new(STDOUT, level: ENV['LOG_LEVEL'] || 'info')

    stub_request(:post, "#{ENV['NYPL_OAUTH_URL']}oauth/token").to_return(status: 200, body: '{ "access_token": "fake-access-token" }')
    stub_request(:get, "#{ENV['PLATFORM_API_BASE_URL']}items/sierra-nypl/37314241").to_return(status: 200, body: File.read('./spec/fixtures/item_37314241.json'))
  end

  it "should authenticate when calling with :authenticate => true" do
    client = PlatformApiClient.new

    # Verify no access token:
    expect(client.instance_variable_get(:@access_token)).to be_nil

    # Call an endpoint with authentication:
    expect(client.get('items/sierra-nypl/37314241', authenicate: true)).to be_a(Object)

    # Verify access_token retrieved:
    expect(client.instance_variable_get(:@access_token)).to be_a(String)
    expect(client.instance_variable_get(:@access_token)).to eq('fake-access-token')
  end
end
