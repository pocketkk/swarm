#  milvus_db_bot.rb

begin
  require_relative 'nanny/lib/nanny'
  require 'milvus'

  LOG_PATH = "/app/logs/milvus_db_bot_"

  class MilvusDbBot < Nanny::NannyBot
    USER = 1
    AGENT = 2

    subscribe_to_channel ENV['CHANNEL_NAME'],
      types: ENV['EVENT_TYPES'].split(',').map(&:to_sym),
      callback: :process_event

    def initialize
      super

      @collection = 'conversations'
      tell_mother("Initializing Milvus Client ...")
      @client = Milvus::Client.new(url: 'http://milvus-standalone:9091')
      result = @client.collections.load(collection_name: @collection)
    end

    def create_collection(collection_name)
      uri = URI.parse("http://milvus-standalone:9091/api/v1/collection")

      header = {'Content-Type': 'application/json', 'Accept': 'application/json'}

      schema = {
        "autoID" => false,
        "description" => "Conversations",
        "fields" => [
          {
            "name" => "postgres_id",
            "description" => "ID from postgres",
            "is_primary_key" => true,
            "autoID" => false,
            "data_type" => 5
          },
          {
            "name" => "timestamp",
            "description" => "UNIX timestamp",
            "is_primary_key" => false,
            "data_type" => 5
          },
          {
            "name" => "embedding",
            "description" => "embedded vector of conversation",
            "data_type" => 101,
            "is_primary_key" => false,
            "type_params" => [
              {
                "key" => "dim",
                "value" => "1536"
              }
            ]
          }
        ],
        "name" => "conversations"
      }

      http = Net::HTTP.new(uri.host, uri.port)

      request = Net::HTTP::Post.new(uri.request_uri, header)
      request.body = {
        collection_name: collection_name,
        schema: schema
      }.to_json

      response = http.request(request)

      tell_mother(response.body)

    rescue => e
      handle_error(e)

      raise e
    end

    private

    attr_reader :collection, :client

    def process_event(event)
      tell_mother('Processing event ...')

      tell_mother("Initializing Milvus Client ...")
      @client = Milvus::Client.new(url: 'http://milvus-standalone:9091')
      @client.collections.load(collection_name: @collection)

      @postgres_id = event['postgres_id']

      #client.collections.get(collection_name: @collection)
      response = process_message(event['message'])
      publish_response(response, event['type'])
    end


    def process_message(message)
      tell_mother("Processed Message ...")

      result = client.entities.insert(
        collection_name: collection,
        num_rows: 1,
        fields_data: [
          { "field_name": "postgres_id", "type": Milvus::DATA_TYPES["int64"], "field": [@postgres_id.to_i] },
          { "field_name": "timestamp", "type": Milvus::DATA_TYPES["int64"], "field": [unix_timestamp] },
          { "field_name": "embedding", "type": 101, "field": [message]}
        ]
      )

      tell_mother("ID: #{@postgres_id} - Embedded: #{message.size}")

      result.to_s
    rescue => e
      handle_error(e)
    end

    def publish_response(response, type)
      result = publish(
        channel:  'events',
        message: { type: :agent_input, agent: ENV['CHANNEL_NAME'], message: "(#{type}): Saved to memory." }.to_json
      )

      tell_mother("Published message: Saved to memory, Publish result: #{result}")
    end

    def unix_timestamp
      Time.now.to_i
    end
  end

  MilvusDbBot.new.run
rescue => e
  Logger.new(LOG_PATH).error(e.message)
  Logger.new(LOG_PATH).error(e.backtrace.join("\n"))
  Logger.new(LOG_PATH).info("Rescue me please!, waiting ...")

  loop { sleep 100 }
end


