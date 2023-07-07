class ServiceNanny
  attr_reader :redis, :postgres

  def initialize(*services)
    @services = services
  end

  def start
    @services.each do |service|
      case service
      when :redis
        @redis = initialize_redis
      when :postgres
        @postgres = initialize_postgres
      else
        raise "Unknown service: #{service}"
      end
    end

    self
  end

  private

  def initialize_redis
    # Initialize your Redis service here and return the instance
    # This is just an example, replace with your actual Redis initialization code
    Redis.new(host: 'redis_container', port: 6379)
  end

  def initialize_postgres
    # Initialize your Postgres service here and return the instance
    # This is just an example, replace with your actual Postgres initialization code
    PGClient.new('postgres_container', 'postgres', 'postgres', 'postgres')
  end
end

