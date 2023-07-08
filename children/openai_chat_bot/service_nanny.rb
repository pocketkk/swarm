require 'pg'
require_relative 'subscribe'

class ServiceNanny

  attr_reader :redis, :postgres, :logger, :options

  def initialize(*services)
    @options = services.last.is_a?(Hash) ? services.pop : {}
    @services = services
    start
  end

  def start
    @services.each do |service|
      case service
      when :redis
        @redis = initialize_redis
      when :postgres
        @postgres = initialize_postgres

        initialize_tables
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

    puts message[0, 50]
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
    unless @postgres.table_exists?('embedding_texts')
      table_name = 'embedding_texts'
      options_hash = {
        id: 'serial PRIMARY KEY',
        content: :string,
        embeddings_id: :string,
        created_at: 'timestamp DEFAULT CURRENT_TIMESTAMP'
      }

      @pg_client.create_table(table_name, options_hash)
    end
  end
end

