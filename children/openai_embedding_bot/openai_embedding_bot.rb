# openai_embedding_agent.rb
require 'net/http'
require 'uri'
require 'json'
require 'redis'
require 'logger'

class OpenAIEmbeddingAgent
  API_ENDPOINT = 'https://api.openai.com/v1/embeddings'
  MODEL = 'text-embedding-ada-002'
  CONTENT_TYPE = 'application/json'
  LOG_PATH = '/app/logs/open_ai_embedding_agent_'

  def initialize(redis_host, redis_port)
    @redis_host = redis_host
    @redis_port = redis_port
    @logger = initialize_logger
    @redis_client = initialize_redis
  end

  def run
    startup
    listen_to_agents
    process_messages
  rescue => e
    handle_error(e)
  ensure
    shutdown
  end

  private

  def initialize_logger
    Logger.new(LOG_PATH + timestamp + '.log')
  end

  def initialize_redis
    Redis.new(host: @redis_host, port: @redis_port)
  end

  def startup
    puts 'Starting up ...'
    log_info("Starting up")
  end

  def shutdown
    log_info("Shutting down")
  end

  def timestamp
    Time.now.strftime('%Y%m%d')
  end

  def handle_error(error)
    log_error("Error: #{error}")
    log_error("Backtrace: #{error.backtrace.join("\n")}")
    puts 'An error occurred (see logs)'

    puts 'Restarting process messages.'
    process_messages
  end

  def get_embedding(message, api_key = nil)
    log_info("Received Message: #{message}")
    uri = URI(API_ENDPOINT)

    key = api_key || ENV['OPENAI_API_KEY']
    request = create_request(uri, key, message)

    response = send_request(uri, request)
    parse_response(response)
  rescue StandardError => e
    handle_error(e)
  end

  def create_request(uri, key, message)
    request = Net::HTTP::Post.new(uri)
    request['Authorization'] = "Bearer #{key}"
    request['Content-Type'] = CONTENT_TYPE
    request.body = JSON.dump({
      'model' => MODEL,
      'input' => message
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
    data = json_response['data']
    data&.first&.dig('embedding')
  end

  def listen_to_agents
    puts 'Listening ...'
    log_info("Listening:")
    @listening_agents = Thread.new do
      log_info("Starting Thread:")
      @redis_client.subscribe('events') do |on|
        log_info("Subscribing ...")
        on.message do |_channel, message|
          log_info("Message Received: #{message}")
          puts 'Received message'
          event = JSON.parse(message)
          @postgres_id = event['postgres_id']
          process_event(event, :user) if event['type'] == 'persist_user_input'
          process_event(event, :agent) if event['type'] == 'persist_agent_input'
        end
      end
    end
  rescue => e
    handle_error(e)
  end

  def process_event(event, type)
    puts 'Processing event ...'
    response = process_message(event['message'])
    publish_response(response, type)
  rescue => e
    handle_error(e)
  end

  def process_messages
    loop do
      sleep 1
    end
  end

  def process_message(message)
    response = get_embedding(message)
    puts "Processed Message."
    log_info("Processed Message: #{message}")
    log_info("Response: #{response[0..10]}")
    response
  end

  def publish_response(response, type)
    log_info("Publishing Response: #{response}")
    requester = type == :user ? :new_user_embedding : :new_agent_embedding

    result = @redis_client.publish('events', { type: requester, id: @postgres_id, agent: 'openai_embedding_agent', message: response}.to_json)

    log_info("Published message: #{response}, Publish result: #{result}")
    puts 'Published message.'
    response
  end

  def log_info(message)
    @logger.info("#{self.class.name} - #{message}")
  end

  def log_error(message)
    @logger.error("#{self.class.name} - #{message}")
  end
end

# Example usage
redis_host = 'redis_container'
redis_port = 6379

agent = OpenAIEmbeddingAgent.new(redis_host, redis_port)
agent.run
