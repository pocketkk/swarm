# weather_bot.rb
begin
  require_relative 'nanny/lib/nanny'
  require 'json'
  require 'uri'

  LOG_PATH = '/app/logs/weather_bot_'

  class WeatherBot < Nanny::NannyBot

    subscribe_to_channel ENV['CHANNEL_NAME'],
      types: ENV['EVENT_TYPES'].split(',').map(&:to_sym),
      callback: :process_event

    def process_event(event)
      tell_mother('Processing event ...')

      location = event['message']

      weather = weather_service.get_weather(location)

      publish_response(weather)
    rescue => e
      tell_mother("Error: #{e.message}")
      tell_mother("Backtrace: #{e.backtrace.join("\n")}")

      publish_response("No bueno! #{e.message}")
    end

    def publish_response(response)
      publish(channel: 'openai_chat', message: { type: :agent_input, agent: ENV['CHANNEL_NAME'], message: "Please provide a one sentence summary: #{response}"}.to_json)
      result = publish(channel: 'events', message: { type: :agent_input, agent: ENV['CHANNEL_NAME'], message: response}.to_json)
      tell_mother("Published message: #{response}, Publish result: #{result}")

      response
    end
  end

  WeatherBot.new.run
rescue => e
  Logger.new(LOG_PATH).error(e.message)
  Logger.new(LOG_PATH).error(e.backtrace.join("\n"))
  Logger.new(LOG_PATH).info("Rescue me please!, waiting ...")

  loop { sleep 100 }
end
