# milvus_db_bot.py

require 'net/http'
require 'uri'
require 'json'
require 'redis'
require 'logger'
require 'milvus'

class MilvusDbBot
  LOG_PATH = "/app/logs/milvus_db_bot_"
  USER = 1
  AGENT = 2

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
    @collection = 'conversations'
    @client = Milvus::Client.new(url: 'http://milvus-standalone:9091')


    # Get the collection info
    client.collections.get(collection_name: @collection)
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

  attr_reader :redis_client, :collection, :client

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

  def listen_to_agents
    puts 'Listening ...'
    log_info("Listening:")
    @listening_agents = Thread.new do
      begin
        log_info("Starting Thread:")
        @redis_client.subscribe('milvus') do |on|
          log_info("Subscribing ...")
          @logger.info('Subscribing .....')
          on.message do |_channel, message|
            begin
              @logger.info("Message Received: #{message[0..10]}")
              puts 'Received message'
              event = JSON.parse(message)
              log_info("Event Agent: #{event['agent']}")
              unless event['agent'] == 'milvus_db_bot'
                process_event(event, :user) if event['type'] == 'save_user_embeddings'
                process_event(event, :agent) if event['type'] == 'save_agent_embeddings'
              end
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

  def process_event(event, type)
    puts 'Processing event ...'
    @logger.info('Processing event ...')
    response = process_message(event['message'], type)
    publish_response(response, type)
  end

  def process_messages
    loop do
      sleep 1
    end
  end

  def unix_timestamp
    Time.now.to_i
  end

  def random_id
    SecureRandom.random_number(100_000_000)
  end

  def process_message(message, user)
    speaker_id = user == :user ? USER : AGENT

    log_info("Processed Message for #{speaker_id}.")
    # TODO: Add logic to process message

     result = client.entities.insert(
      collection_name: @collection,
      num_rows: 1,
      fields_data: [
        { "field_name": "id", "type": Milvus::DATA_TYPES["int64"], "field": ["#{unix_timestamp}#{random_id}".to_i] },
        { "field_name": "timestamp", "type": Milvus::DATA_TYPES["int64"], "field": [unix_timestamp] },
        { "field_name": "speaker", "type": Milvus::DATA_TYPES["int16"], "field": [speaker_id] },
        { "field_name": "embedding", "type": 101, "field": [message]}
      ]
    )
   log_info("Collection: #{client.collections.get(collection_name: @collection).to_s}")
   log_info("Result: #{result.to_s}")
   log_info("Embeddings: #{message}")

   result.to_s
  rescue => e
    puts e
    log_info("Error: #{e}")
    log_info("Backtrace: #{e.backtrace.join('\n')}")
    raise e
  end

  def publish_response(response, type)
    result = @redis_client.publish('events', { type: :agent_input, agent: 'milvus_db_bot', message: "(#{type}): Saved to memory."}.to_json)
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

redis_host = 'redis_container'
redis_port = 6379

bot = MilvusDbBot.new(redis_host, redis_port)
puts bot.inspect
bot.run
