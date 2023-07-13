# milvus_db_bot.rb

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

    private

    attr_reader :collection, :client

    def process_event(event)
      type = event['type'].to_sym
      tell_mother('Processing event ...')

      @collection = 'conversations'
      @client = Milvus::Client.new(url: 'http://milvus-standalone:9091')

      @postgres_id = event['postgres_id'] || random_id

      client.collections.get(collection_name: @collection)
      response = process_message(event['message'], event['type'])
      publish_response(response, event['type'])
    end


    def process_message(message, user)
      speaker_id = user == :user ? USER : AGENT

      tell_mother("Processed Message for #{speaker_id}.")

      result = client.entities.insert(
        collection_name: @collection,
        num_rows: 1,
        fields_data: [
          { "field_name": "id", "type": Milvus::DATA_TYPES["int64"], "field": [@postgres_id.to_i] },
          { "field_name": "timestamp", "type": Milvus::DATA_TYPES["int64"], "field": [unix_timestamp] },
          { "field_name": "speaker", "type": Milvus::DATA_TYPES["int16"], "field": [speaker_id] },
          { "field_name": "embedding", "type": 101, "field": [message]}
        ]
      )

      tell_mother("ID: #{@postgres_id} - Embedded: #{message}")

      result.to_s
    rescue => e
      handle_error(e)
    end

    def publish_response(response, type)
      result = publish(
        channel:  'events',
        message: { type: :agent_input, agent: 'milvus_db_bot', message: "(#{type}): Saved to memory."}.to_json
      )

      tell_mother("Published message: #{response}, Publish result: #{result}")
    end

    def unix_timestamp
      Time.now.to_i
    end

    def random_id
      SecureRandom.random_number(100_000_000)
    end
  end

  MilvusDbBot.new.run
rescue => e
  Logger.new(LOG_PATH).error(e.message)
  Logger.new(LOG_PATH).error(e.backtrace.join("\n"))
  Logger.new(LOG_PATH).info("Rescue me please!, waiting ...")

  loop { sleep 100 }
end


