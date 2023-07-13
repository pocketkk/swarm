# openai_chat_bot.rb
begin
  require_relative 'nanny/lib/nanny'

  LOG_PATH = '/app/logs/open_ai_chatbot_'

  class OpenAIChatBot < Nanny::NannyBot

    subscribe_to_channel ENV['CHANNEL_NAME'],
      types: ENV['EVENT_TYPES'].split(',').map(&:to_sym),
      callback: :process_event

    private

    def process_event(event)
      tell_mother('Processing event ...')
      response = chat(event['message'])

      persist_message(event['message'], 'embed_user_input')
      persist_message(response, 'embed_agent_response')

      publish_response(response)
    end

    def persist_message(message, type)
      id = save_message(message: message, source: type)

      result = publish(
        channel: 'embeddings',
        message: { type: type, postgres_id: id, message: message}.to_json
      )
      tell_mother("Persisted message: #{message}, Persist result: #{id}, #{result}")
    end

    def publish_response(response)
      result = publish(channel: 'events', message: { type: :agent_input, agent: 'openai_chat_bot', message: response}.to_json)
      tell_mother("Published message: #{response}, Publish result: #{result}")

      response
    end
  end

  OpenAIChatBot.new.run
rescue => e
  Logger.new(LOG_PATH).error(e.message)
  Logger.new(LOG_PATH).error(e.backtrace.join("\n"))
  Logger.new(LOG_PATH).info("Rescue me please!, waiting ...")

  loop { sleep 100 }
end
