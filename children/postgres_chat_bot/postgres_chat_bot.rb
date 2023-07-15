# openai_chat_bot.rb
begin
  require_relative 'nanny/lib/nanny'

  LOG_PATH = '/app/logs/postgres_chatbot_'

  class PostgresChatBot < Nanny::NannyBot

    subscribe_to_channel ENV['CHANNEL_NAME'],
      types: ENV['EVENT_TYPES'].split(',').map(&:to_sym),
      callback: :process_event

    private

    def process_event(event)
      tell_mother('Processing event ...')

      response = @nanny.postgres.messages_by_ids(event['message'])

      publish_response(response)
    end

    def publish_response(response)
      result = publish(channel: 'events', message: { type: :agent_input, agent: ENV['CHANNEL_NAME'], message: response}.to_json)

      tell_mother("Published message: #{response}, Publish result: #{result}")

      response
    end
  end

  PostgresChatBot.new.run
rescue => e
  Logger.new(LOG_PATH).error(e.message)
  Logger.new(LOG_PATH).error(e.backtrace.join("\n"))
  Logger.new(LOG_PATH).info("Rescue me please!, waiting ...")

  loop { sleep 100 }
end
