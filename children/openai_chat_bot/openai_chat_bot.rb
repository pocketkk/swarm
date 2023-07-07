# openai_chat_bot.rb
require 'net/http'
require 'uri'
require 'json'
require 'redis'
require 'logger'
require_relative 'pg_client'
require_relative 'service_nanny'

class OpenAIChatBot
  API_ENDPOINT = 'https://api.openai.com/v1/chat/completions'
  MODEL = 'gpt-3.5-turbo'
  CONTENT_TYPE = 'application/json'
  LOG_PATH = '/app/logs/open_ai_chatbot_'

  def initialize
    @nanny = ServiceNanny.new(:redis, :postgres, :logger, { log_path: LOG_PATH })
  rescue => e
    @nanny.handle_error(e)
  end

  def run
    startup
    listen_to_agents
    process_messages
  rescue => e
    @nanny.handle_error(e)
  ensure
    shutdown
  end

  private

  def startup
    @nanny.tell_mother('Starting up ...')
    @nanny.logger.info("Starting up")
  end

  def shutdown
    @nanny.tell_mother('Shutting down ...')
    @nanny.logger.info("Shutting down")
  end

  def get_chat(message, api_key = nil)
    @nanny.logger.info("Received Message: #{message}")
    @nanny.tell_mother("Message Received")

    uri = URI(API_ENDPOINT)

    key = api_key || ENV['OPENAI_API_KEY']
    request = create_request(uri, key, message)

    response = send_request(uri, request)
    parse_response(response)
  rescue StandardError => e
    @nanny.handle_error(e)
  end

  def create_request(uri, key, message)
    request = Net::HTTP::Post.new(uri)
    request['Authorization'] = "Bearer #{key}"
    request['Content-Type'] = CONTENT_TYPE
    request.body = JSON.dump({
      'model' => MODEL,
      'messages' => [
        { 'role' => 'user', 'content' => message }
      ],
      'temperature' => 0.5
    })

    request
  end

  def send_request(uri, request)
    Net::HTTP.start(uri.hostname, uri.port, use_ssl: uri.scheme == 'https') do |http|
      http.request(request)
    end
  end

  def parse_response(response)
    json_response = JSON.parse(response.body)
    choices = json_response['choices']
    choices&.first&.dig('message', 'content')&.strip
  end

  def listen_to_agents
    @nanny.tell_mother('Listening ...')
    @nanny.logger.info("Listening:")

    @listening_agents = Thread.new do
      begin
        @nanny.logger.info("Starting Thread:")
        @nanny.redis.subscribe('events') do |on|
          @nanny.logger.info("Subscribing ...")
        on.message do |_channel, message|
          begin
            @nanny.logger.info("Message Recieved: #{message}")
            @nanny.tell_mother('Received message')
            event = JSON.parse(message)
            process_event(event) if event['type'] == 'user_input'
          rescue => e
            @nanny.handle_error(e)
          end
        end
        end
      rescue => e
        @nanny.handle_error(e)
      end
    end
  rescue => e
    @nannt.handle_error(e)
  end

  def process_event(event)
    puts 'Processing event ...'
    id = persist_message(event['message'], 'persist_user_input')
    response = process_message(event['message'])
    id_response = persist_message(response, 'persist_agent_input')
    publish_response(response)
  end

  def persist_message(message, type)
    id = @nanny.postgres.save_message(message)
    result = @nanny.redis.publish('events', { type: type, postgres_id: id, message: message}.to_json)
    @nanny.logger.info("Persisted message: #{message}, Persist result: #{id}, #{result}")

    @nanny.tell_mother 'Persisted message.'
    id
  end

  def process_messages
    loop do
      sleep 1
    end
  end

  def process_message(message)
    @nanny.logger.info("Processing Message: #{message}")
    response = get_chat(message)
    @nanny.tell_mother("Processed Message.")
    @nanny.logger.info("Processed Message: #{message}")
    response
  rescue => e
    @nanny.handle_error(e)
  end

  def publish_response(response)
    result = @nanny.redis.publish('events', { type: :agent_input, agent: 'openai_chat_bot', message: response}.to_json)
    @nanny.logger.info("Published message: #{response}, Publish result: #{result}")
    @nanny.tell_mother('Published message.')
    response
  end
end

OpenAIChatBot.new.run
