# chroma_db_bot.rb

require 'net/http'
require 'uri'
require 'json'
require 'redis'
require 'logger'
require 'chroma-db'

class ChromaDbBot
  LOG_PATH = "/app/logs/chroma_db_bot_"

  def initialize(redis_host, redis_port)
    @logger = initialize_logger
    puts 'Logger'
    @logger.info('Logger created')
    @redis_host = redis_host
    @logger.info('Redis Host')
    @redis_port = redis_port
    @logger.info('Redis Port')
    @redis_client = initialize_redis
    @logger.info('Redis Client')
    Chroma.connect_host = 'http://chroma_server_1:8000'
    @logger.info('Chroma Host')
    Chroma.logger = @logger
    @logger.info('Chroma Logger')
    Chroma.log_level = Chroma::LEVEL_ERROR
    @logger.info('Chroma Level')
    #@collection = Chroma::Resources::Collection.create('AgentsHistory', {lang: "ruby", gem: "chroma-db"})
    @collection = Chroma::Resources::Collection.get('AgentsHistory')
    @logger.info('Chroma Collection')
  rescue => e
    @logger.error("Error")
    log_info("Error: #{e}")
    log_info("Backtrace: #{e.backtrace.join('/n')}")
    puts 'oops'
  end

  def run
    startup
    listen_to_agents
    process_messages
  rescue => e
    #handle_error(e)
  ensure
    shutdown
  end

  private

  attr_reader :redis_client, :collection

  def initialize_logger
    Logger.new(LOG_PATH + "#{timestamp}.log")
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
    log_error("Backtrace: #{error.backtrace}")
    puts 'Shit there was an error (see logs)'

    #puts 'Restarting process messages.'
    #process_messages
  end

  #def listen_to_agents
  #puts 'Listening ...'
  #@logger.info('Listening ...')
  #@listening_agents = Thread.new do
  #@redis_client.subscribe('events') do |on|
  #on.message do |_channel, message|
  #puts 'Received message'
  #event = JSON.parse(message)
  #process_event(event)
  #end
  #end
  #end
  #end

  def listen_to_agents
    puts 'Listening ...'
    log_info("Listening:")
    @listening_agents = Thread.new do
      begin
        log_info("Starting Thread:")
        @redis_client.subscribe('events') do |on|
          log_info("Subscribing ...")
          @logger.info('Subscribing .....')
          on.message do |_channel, message|
            begin
              @logger.info("Message Recieved: #{message}")
              puts 'Received message'
              event = JSON.parse(message)
              process_event(event) if event['type'] == 'user_input'
            rescue => e
              log_info("Error: #{e}")
              log_info("Backtrace: #{e.backtrace.join('\n')}")
              raise e
            end
          end
        end
      rescue => e
        log_info("Error: #{e}")
        log_info("Backtrace: #{e.backtrace.join('\n')}")
        raise e
      end
    end
  rescue => e
    log_info("Error: #{e}")
    log_info("Backtrace: #{e.backtrace.join('\n')}")
    handle_error(e)
  end

  def process_event(event)
    puts 'Processing event ...'
    @logger.info('Processing event ...')
    response = process_message(event['message'])
    #publish_response(response)
  end

  def process_messages
    loop do
      sleep 1
    end
  end

  def process_message(message)
# Check current Chrome server version
version = Chroma::Resources::Database.version
puts version

    puts "Starting Embedding"
    @logger.info("Starting Embedding")
# Create a new collection
#new_collection = Chroma::Resources::Collection.create('TestMemory2', {lang: "ruby", gem: "chroma-db"})

    @collection = Chroma::Resources::Collection.get('TestMemory')
# Add embeddings
embeddings = [
  Chroma::Resources::Embedding.new(id: "1", embedding: [1.5, 2.6, 3.1], metadata: {client: "chroma-rb"}, document: "ruby"),
  Chroma::Resources::Embedding.new(id: "2", embedding: [3.8, 2.8, 0.9], metadata: {client: "chroma-rb"}, document: "rails")
]

@logger.info("Collection ID: #{collection.inspect}")
@logger.info("Embeddings: #{")
#@logger.info("New Collection: #{new_collection.inspect}")
@collection.upsert(embeddings)

    # do stuff here

    #embeddings = [
      #Chroma::Resources::Embedding.new(
        #id: SecureRandom.hex(6) + "#{Time.now.strftime('%Y%m%d')}",
        #embedding: [1.3,2.5,3.1],
        #metadata: {client: "chroma-rb"},
        #document: "ruby"
      #)
    #]

    @logger.info("Embeddings: #{embeddings}")
    @logger.info("Collection: #{new_collection.inspect}")

    #collection.add(embeddings)

    puts "Embedded text."
    log_info("Processed Message: #{embeddings}")
  rescue => e
    puts e
    log_info("Error: #{e}")
    log_info("Backtrace: #{e.backtrace.join('\n')}")
    raise e
  end

  def publish_response(response)
    #result = @redis_client.publish('events', { type: :agent_input, agent: 'openai_chat_bot', message: response}.to_json)
    #log_info("Published message: #{response}, Publish result: #{result}")
    #puts 'Published message.'
    #response
  end

  def log_info(message)
    @logger.info("#{self.class.name} - #{message}")
  end

  def log_error(message)
    @logger.error("#{self.class.name} - #{message}")
  end
end

redis_host = 'redis_container'
redis_port = 6379

bot = ChromaDbBot.new(redis_host, redis_port)
puts bot.inspect
bot.run
