# milvus_search_bot.rb

begin
  require_relative 'nanny/lib/nanny'
  require 'milvus'

  LOG_PATH = "/app/logs/milvus_search_bot_"

  class MilvusSearchBot < Nanny::NannyBot
    USER = 1
    AGENT = 2

    subscribe_to_channel :milvus_search,
      types: [:user_input, :agent_input],
      callback: :process_event

    private

    attr_reader :collection, :client

    def process_event(event)
      type = event['type'].to_sym
      tell_mother('Processing event ...')

      @collection = 'conversations'
      @client = Milvus::Client.new(url: 'http://milvus-standalone:9091')

      response = search_message(event['message'])
      publish_response(response, event['type'])
    end

    def search_message(message)
      tell_mother("Searching Message: #{message}.")

      embedding = get_embedding(message)

      client.collections.get(collection_name: @collection)
      client.collections.load(collection_name: @collection)

      result = client.search(
        collection_name: @collection,
        output_fields: ["id"],
        anns_field: "embedding",
        top_k: "5",
        params: "{\"nprobe\": 10}",
        metric_type: "L2",
        round_decimal: "-1",
        vectors: [embedding],
        dsl_type: 1
      )

      client.collections.release(collection_name: @collection)

      ids = result["results"]["fields_data"][0]["Field"]["Scalars"]["Data"]["LongData"]["data"]

      tell_mother("Search Result: #{ids.class.name} | #{ids}")

      tell_mother("Search Result: #{result}")

      result.to_s
    rescue => e
      handle_error(e)
    end

    def publish_response(response, type)
      result = publish(
        channel:  'events',
        message: { type: :agent_input, agent: 'milvus_search_bot', message: "(#{type}): Search Result: #{response}"}.to_json
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
