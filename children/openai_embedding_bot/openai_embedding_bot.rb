# openai_embedding_agent.rb
begin
  require_relative 'nanny/lib/nanny'

  LOG_PATH = '/app/logs/open_ai_embedding_agent_'

  class OpenAIEmbeddingAgent < Nanny::NannyBot

    subscribe_to_channel ENV['CHANNEL_NAME'],
      types: ENV['EVENT_TYPES'].split(',').map(&:to_sym),
      callback: :process_event

    private

    def process_event(event)
      type = event['type'] == 'embed_user_input' ? :user : :agent

      tell_mother("Processing event: #{event}")

      response = @nanny.get_embedding(event['message'])
      @postgres_id = event['postgres_id']
      publish_response(response, type)
    rescue => e
      handle_error(e)
    end

    def publish_response(response, type)
      tell_mother("Publishing Response: #{response}")

      requester = type == :user ? 'save_user_embeddings' : 'save_agent_embeddings'

      result = publish(
        channel: 'milvus',
        message: {
          type: requester,
          id: @postgres_id,
          agent: ENV['CHANNEL_NAME'],
          message: response
        }.to_json
      )

      tell_mother("Published message: #{response}, Publish result: #{result}")
      response
    end
  end

  OpenAIEmbeddingAgent.new.run
rescue => e
  Logger.new(LOG_PATH).error(e.message)
  Logger.new(LOG_PATH).error(e.backtrace.join("\n"))
  Logger.new(LOG_PATH).info("Rescue me please!, waiting ...")

  loop { sleep 100 }
end
