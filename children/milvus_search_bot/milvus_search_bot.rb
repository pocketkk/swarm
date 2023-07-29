# milvus_search_bot.rb

begin
  require_relative 'nanny/lib/nanny'
  require 'milvus'

  LOG_PATH = "/app/logs/milvus_search_bot_"

  class MilvusSearchBot < Nanny::NannyBot
    USER = 1
    AGENT = 2

    subscribe_to_channel ENV['CHANNEL_NAME'],
      types: ENV['EVENT_TYPES'].split(',').map(&:to_sym),
      callback: :process_event

    def initialize
      super

      @collection = 'conversations'
      @client = Milvus::Client.new(url: 'http://milvus-standalone:9091')
      tell_mother("Client Health: #{client.health}")
      load_response = load_collection(@collection)
      tell_mother("Client Loaded: #{load_response}")
    end

    private

    def load_collection(collection_name)
      uri = URI.parse("http://milvus-standalone:9091/api/v1/collection/load")

      header = {'Content-Type': 'application/json', 'Accept': 'application/json'}

      http = Net::HTTP.new(uri.host, uri.port)

      request = Net::HTTP::Post.new(uri.request_uri, header)
      request.body = {
        collection_name: collection_name
      }.to_json

      response = http.request(request)

      response.body
    end

    def create_index(collection_name, field_name)
      uri = URI.parse("http://milvus-standalone:9091/api/v1/index")

      extra_params = [
        {"key" => "metric_type", "value" => "L2"},
        {"key" => "index_type", "value" => "IVF_FLAT"},
        {"key" => "params", "value" => "{\"nlist\":1024}"}
      ]

      header = {'Content-Type': 'application/json', 'Accept': 'application/json'}

      http = Net::HTTP.new(uri.host, uri.port)

      request = Net::HTTP::Post.new(uri.request_uri, header)
      request.body = {
        collection_name: collection_name,
        field_name: field_name,
        extra_params: extra_params
      }.to_json

      response = http.request(request)

      response.body
    end

    attr_reader :collection, :client

    def process_event(event)
      type = event['type'].to_sym
      tell_mother('Processing event ...')


      response = search_message(event['message'])
      publish_response(response, event['type'])
    end

    def search_message(message)
      tell_mother("Searching Message: #{message}.")

      embedding = get_embedding(message)

      #result = client.collections.load(collection_name: @collection)
      #tell_mother("Collection loaded: #{result}")

      result = client.search(
        collection_name: @collection,
        output_fields: ["postgres_id"],
        anns_field: "embedding",
        top_k: "2",
        params: "{\"nprobe\": 10}",
        metric_type: "L2",
        round_decimal: "-1",
        vectors: [embedding],
        dsl_type: 1
      )

      #client.collections.release(collection_name: @collection)
      tell_mother("Search Result: #{result}.")

      data = result.dig("results", "fields_data", 0, "Field", "Scalars", "Data", "LongData", "data")
      return 'No results found' if data.nil?

      #data = result["results"]["fields_data"][0]["Field"]["Scalars"]["Data"]["LongData"]["data"]

      tell_mother("Search Result: #{data.class.name} | #{data}")
      tell_mother("Search Result: #{result}")

      result.to_s
    rescue => e
      handle_error(e)
    end

    def publish_response(response, type)
      result = publish(
        channel:  'events',
        message: { type: :agent_input, agent: ENV['CHANNEL_NAME'], message: "(#{type}): Search Result: #{response}"}.to_json
      )

      tell_mother("Published message: #{response}, Publish result: #{result}")
    end
  end

  MilvusSearchBot.new.run

rescue => e
  Logger.new(LOG_PATH).error(e.message)
  Logger.new(LOG_PATH).error(e.backtrace.join("\n"))
  Logger.new(LOG_PATH).info("Rescue me please!, waiting ...")

  loop { sleep 100 }
end
