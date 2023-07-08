# openai_chat_bot.rb
require 'net/http'
require 'uri'
require 'json'
require 'redis'
require 'logger'
require_relative 'pg_client'
require_relative 'service_nanny'
require_relative 'openai_service'

class OpenAIChatBot
  LOG_PATH = '/app/logs/open_ai_chatbot_'

  def initialize
    @nanny = ServiceNanny.new(:redis, :postgres, :logger, { log_path: LOG_PATH })
    @openai = OpenAIService.new(ENV['OPENAI_API_KEY'])

    @nanny.tell_mother('Initializing ...')
  rescue => e
    @nanny.handle_error(e)
  end

  def run
    @nanny.tell_mother('Starting up ...')
    listen_to_agents

    loop do
      sleep 1
    end
  rescue => e
    @nanny.handle_error(e)
  ensure
    @nanny.tell_mother('Shutting down ...')
  end

  private

  def listen_to_agents
    @nanny.tell_mother('Listening ...')

    @nanny.subscribe(channel: 'events', types: [:user_input]) do |message|
      @nanny.tell_mother("Received message: #{message}")
      process_event(message)
    end
  rescue => e
    @nanny.handle_error(e)
  end

  def process_event(event)
    @nanny.tell_mother('Processing event ...')
    response = @openai.chat(event['message'])

    id = persist_message(event['message'], 'persist_user_input')
    id_response = persist_message(response, 'persist_agent_input')

    publish_response(response)
  end

  def persist_message(message, type)
    id = @nanny.postgres.save_message(message)

    result = @nanny.publish(
      channel: 'events',
      message: { type: type, postgres_id: id, message: message}.to_json
    )
    @nanny.tell_mother("Persisted message: #{message}, Persist result: #{id}, #{result}")

    id
  end

  def publish_response(response)
    result = @nanny.publish(channel: 'events', message: { type: :agent_input, agent: 'openai_chat_bot', message: response}.to_json)
    @nanny.tell_mother("Published message: #{response}, Publish result: #{result}")
    response
  end
end

OpenAIChatBot.new.run
