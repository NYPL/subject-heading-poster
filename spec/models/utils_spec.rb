require 'spec_helper'

describe "#discovery_id" do
  it "should derive the `discovery_id` from the `id` and `nypl_source`" do
    discovery_id = discovery_id("sierra-nypl", "12345")

    expect(discovery_id).to eq("b12345")
  end
end
