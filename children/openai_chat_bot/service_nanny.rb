require 'pg'
require 'redis'
require 'logger'
require_relative 'subscribe'
require_relative 'pg_client'

class ServiceNanny
  attr_reader :redis, :postgres, :logger, :options

  def initialize(*services)
    @options = services.last.is_a?(Hash) ? services.pop : {}
    @services = services
    @logger = Logger.new(STDOUT)
    start
  end

  def start
    @services.each do |service|
      case service
      when :redis
        @redis = initialize_redis
      when :postgres
        @postgres = initialize_postgres

        #initialize_tables
      when :logger
        raise 'Missing log_path' if options[:log_path].nil?

        @logger = initialize_logger
      else
        raise "Unknown service: #{service}"
      end
    end

    self
  end

  def initialize_logger
    Logger.new(options[:log_path] + timestamp + '.log')
  end

  def timestamp
    Time.now.strftime('%Y%m%d')
  end

  def handle_error(error)
    raise error unless @logger

    @logger.error("Error: #{error}")
    @logger.error("Backtrace: #{error.backtrace.join("\n")}")

    raise error
  end

  def tell_mother(message)
    @logger.info(message) if @logger

    puts "#{message[0, 40]} ..."
  end

  def subscribe(channel:, types:, &callback)
    Subscribe.new(nanny: self, channel: channel, types: types, &callback).start do |event|
      callback.call(event)
    end
  end

  def publish(channel:, message:)
    @redis.publish(channel, message)
  end

  private

  def initialize_redis
    Redis.new(host: 'redis_container', port: 6379)
  end

  def initialize_postgres
    PGClient.new('postgres_container', 'postgres', 'postgres', 'postgres')
  end

  def initialize_tables
    @logger.info('Initializing tables ...')

    unless @postgres.table_exists?('messages')
      @logger.info('Creating table: messages')
      table_name = 'messages'
      options_hash = {
        id: 'serial PRIMARY KEY',
        source: :string,
        content: :string,
        embeddings_id: :string,
        created_at: 'timestamp DEFAULT CURRENT_TIMESTAMP'
      }

      @postgres.create_table(table_name, options_hash)
    end
  end
end

