require 'spec_helper'

describe MWS::Query do
  let(:query_params) {{
    verb: "GET",
    uri: "/",
    host: "mws-eu.amazonservices.com",
    aws_access_key_id: "key",
    aws_secret_access_key: "secret",
    action: "ListOrders",
    seller_id: "Seller ID",
    version: "2010-01-01",
    timestamp: "2013-01-01T00:00:00-02:00"
  }}

  let(:query) {MWS::Query.new(query_params)}

  describe "Initialization" do
    it "should create a MWS::Query object" do
      subject.class.should eq(MWS::Query)
    end

    it "should have some default params" do
      subject.uri.should eq("/")
      subject.verb.should eq("GET")
      subject.signature_method.should eq("HmacSHA256")
      subject.signature_version.should eq(2)
      subject.timestamp.class.should eq(Time)
    end
  end

  describe "Build query" do
    context 'when MWSAuthToken param presents' do
      let(:query_params) { super().merge(mws_auth_token: 'auth_token') }
      let(:generated_query) { "AWSAccessKeyId=key&Action=ListOrders&MWSAuthToken=auth_token&SellerId=Seller+ID&SignatureMethod=HmacSHA256&SignatureVersion=2&Timestamp=2013-01-01T00%3A00%3A00-02%3A00&Version=2010-01-01" }

      it "should build a simple query with MWSAuthToken" do
        query.build_query.should eq(generated_query)
      end
    end

    context 'when MWSAuthTokenParam does not present' do
      let(:generated_query) { "AWSAccessKeyId=key&Action=ListOrders&SellerId=Seller+ID&SignatureMethod=HmacSHA256&SignatureVersion=2&Timestamp=2013-01-01T00%3A00%3A00-02%3A00&Version=2010-01-01" }

      it "should build a simple query without empty MWSAuthToken" do
        query.build_query.should eq(generated_query)
      end
    end

    it "should build a query with a signature" do
      query.build_query("signature").include?("Signature=signature").should eq true
    end

    it "should be a query with custom params" do
      builded_query = MWS::Query.new(query_params.merge(params: {custom_param: "custom"})).build_query
      builded_query.should include("CustomParam=custom")
    end
  end

  describe "canonical string" do
    context 'when MWSAuthToken param presents' do
      let(:query_params) { super().merge(mws_auth_token: 'auth_token') }
      let(:canonical) { "GET\nmws-eu.amazonservices.com\n/\nAWSAccessKeyId=key&Action=ListOrders&MWSAuthToken=auth_token&SellerId=Seller+ID&SignatureMethod=HmacSHA256&SignatureVersion=2&Timestamp=2013-01-01T00%3A00%3A00-02%3A00&Version=2010-01-01" }

      it "should generate a canonical string with MWSAuthToken" do
        query.canonical.should eq(canonical)
      end
    end

    context 'when MWSAuthTokenParam does not present' do
      let(:canonical) { "GET\nmws-eu.amazonservices.com\n/\nAWSAccessKeyId=key&Action=ListOrders&SellerId=Seller+ID&SignatureMethod=HmacSHA256&SignatureVersion=2&Timestamp=2013-01-01T00%3A00%3A00-02%3A00&Version=2010-01-01" }

      it "should generate a canonical string without empty MWSAuthToken" do
        query.canonical.should eq(canonical)
      end
    end
  end

  describe "signature" do
    context 'when MWSAuthToken param presents' do
      let(:query_params) { super().merge(mws_auth_token: 'auth_token') }

      it "should generate a valid signature taking into account MWSAuthToken" do
        query.signature.should eq("rulqZzJFN7YyHfW5kMatF4cXNzxZcOAox6lT97PveCo=")
      end
    end

    context 'when MWSAuthTokenParam does not present' do
      it "should generate a valid signature" do
        query.signature.should eq("7XZO1dSv7BHElkee33Rt7L5PNFiBET13pg3pOWKeoo0=")
      end
    end
  end

  describe "request_uri" do
    context 'when MWSAuthToken param presents' do
      let(:query_params) { super().merge(mws_auth_token: 'auth_token') }
      let(:request_uri) { "https://mws-eu.amazonservices.com/?AWSAccessKeyId=key&Action=ListOrders&MWSAuthToken=auth_token&SellerId=Seller+ID&Signature=rulqZzJFN7YyHfW5kMatF4cXNzxZcOAox6lT97PveCo%3D&SignatureMethod=HmacSHA256&SignatureVersion=2&Timestamp=2013-01-01T00%3A00%3A00-02%3A00&Version=2010-01-01" }

      it "should generate a valid request uri with MWSAuthToken" do
        query.request_uri.should eq(request_uri)
      end
    end

    context 'when MWSAuthTokenParam does not present' do
      let(:request_uri) { "https://mws-eu.amazonservices.com/?AWSAccessKeyId=key&Action=ListOrders&SellerId=Seller+ID&Signature=7XZO1dSv7BHElkee33Rt7L5PNFiBET13pg3pOWKeoo0%3D&SignatureMethod=HmacSHA256&SignatureVersion=2&Timestamp=2013-01-01T00%3A00%3A00-02%3A00&Version=2010-01-01" }

      it "should generate a valid request uri without empty MWSAuthToken" do
        query.request_uri.should eq(request_uri)
      end
    end
  end

  describe MWS::Query::Helpers do
    subject {MWS::Query::Helpers}

    describe "escape_date_time_params(params={})" do
      let(:time) {Time.new(2013, 01, 01)}

      it "should escape a simple hash" do
        subject.escape_date_time_params(time: time).should eq({time: time.iso8601})
      end

      it "should escape a nested hash" do
        subject.escape_date_time_params(time: {time: time}).should eq({time: {time: time.iso8601}})
      end
    end

    describe "camelize_keys(parmas={})" do
      it "should camelize a simple hash" do
        subject.camelize_keys(new_key: "value").should eq("NewKey" => "value")
      end

      it "should camelize a nested hash" do
        subject.camelize_keys(key: {key: "value"}).should eq("Key" => {"Key" => "value"})
      end
    end

    describe "make_structured_lists" do
      it "should return a new structured list" do
        structured_list = subject.make_structured_lists(ids_list: {label: "Id.id", values: [1,2]})
        structured_list.should eq("Id.id.1" => 1, "Id.id.2" => 2)
      end

      it "should return the same hash if there's no list params" do
        structured_list = subject.make_structured_lists(test: "test")
        structured_list.should eq(test: "test")
      end

      it "should return a hash with structured lists and normal values" do
        structured_list = subject.make_structured_lists(test: "test", id_list: {label: "Id.id", values: [1]})
        structured_list.should eq(test: "test", "Id.id.1" => 1)
      end
    end
  end
end
