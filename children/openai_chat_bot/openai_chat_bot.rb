# openai_chat_bot.rb
require 'net/http'
require 'uri'
require 'json'
require 'redis'
require 'logger'
require_relative 'pg_client'

class OpenAIChatBot
  API_ENDPOINT = 'https://api.openai.com/v1/chat/completions'
  MODEL = 'gpt-3.5-turbo'
  CONTENT_TYPE = 'application/json'
  LOG_PATH = '/app/logs/open_ai_chatbot_'

  def initialize(redis_host, redis_port, db_host, db_name, db_user, db_password)
    @redis_host = redis_host
    @redis_port = redis_port
    @db_host = db_host
    @db_name = db_name
    @db_user = db_user
    @db_password = db_password

    @logger = initialize_logger
    sleep(5)
    @redis_client = initialize_redis
    log_info("Starting Initialization: #{@pg_client}")
    log_info("DB HOST: #{db_host} | DB NAME: #{db_name} | DB USER: #{db_user} | DB PASSWORD: #{db_password}")
    @pg_client = PGClient.new(db_host, db_name, db_user, db_password) rescue nil

    #NOTE: Only run once, then comment out
    unless @pg_client.table_exists?('embedding_texts')
      table_name = 'embedding_texts'
      options_hash = {
        id: 'serial PRIMARY KEY',
        content: :string,
        embeddings_id: :string,
        created_at: 'timestamp DEFAULT CURRENT_TIMESTAMP'
      }
      @pg_client.create_table(table_name, options_hash)
    end

    log_info("Initalizing database tables")
    @pg_client.create_table()
    log_info("Initialized: #{@pg_client}")
  rescue => e
    handle_error(e)
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
    puts 'Shit there was an error (see logs)'

    puts 'Restarting process messages.'
    #process_messages
  end

  def get_chat(message, api_key = nil)
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
    puts 'Listening ...'
    log_info("Listening:")
    @listening_agents = Thread.new do
      begin
      log_info("Starting Thread:")
      @redis_client.subscribe('events') do |on|
        log_info("Subscribing ...")
        on.message do |_channel, message|
          begin
          log_info("Message Recieved: #{message}")
          puts 'Received message'
          event = JSON.parse(message)
          process_event(event) if event['type'] == 'user_input'
          rescue => e
            log_info("Error: #{e}")
            log_info("Backtrace: #{e.backtrace.join("\n")}")
            raise e
          end
        end
      end
      rescue => e
        log_info("Error: #{e}")
        log_info("Backtrace: #{e.backtrace.join("\n")}")
        raise e
      end
    end
  rescue => e
    log_info("Error: #{e}")
    log_info("Backtrace: #{e.backtrace.join("\n")}")
    handle_error(e)
  end

  def process_event(event)
    puts 'Processing event ...'
    id = persist_message(event['message'], 'persist_user_input')
    response = process_message(event['message'])
    id_response = persist_message(response, 'persist_agent_input')
    publish_response(response)
  end

  def persist_message(message, type)
    while @pg_client.nil?
      puts 'Waiting for pg client to be initialized.'
      sleep 1
      @pg_client = PGClient.new(@db_host, @db_name, @db_user, @db_password)
    end

    id = @pg_client.save_message(message)
    result = @redis_client.publish('events', { type: type, postgres_id: id, message: message}.to_json)
    log_info("Persisted message: #{message}, Persist result: #{id}, #{result}")
    puts 'Persisted message.'
    id
  end

  def process_messages
    loop do
      sleep 1
    end
  end

  def process_message(message)
    response = get_chat(message)
    puts "Processed Message."
    log_info("Processed Message: #{message}")
    response
  end

  def publish_response(response)
    result = @redis_client.publish('events', { type: :agent_input, agent: 'openai_chat_bot', message: response}.to_json)
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

db_host = 'postgres_container'
db_name = 'postgres'
db_user = 'postgres'
db_password = 'postgres'

bot = OpenAIChatBot.new(redis_host, redis_port, db_host, db_name, db_user, db_password)
bot.run
