# hello_bot.rb
# docker build -t hello_bot .

require 'redis'
require 'json'
require 'pry'
require 'logger'
require 'securerandom'

puts "Starting up ..."
count = 0

@redis = Redis.new(host: '172.27.0.2', port: 6379)
@logger = Logger.new('hello_bot.log')

begin
  loop do
    puts "Generating random string ..."

    #result = @redis.publish('events', { type: :agent_input, agent: 'hello_bot', message: SecureRandom.hex(6) }.to_json)

    #@logger.info("Result #{result}")
    sleep 5
  end
  # Put the logic of your bot here.
rescue => e
  puts "Error: #{e.message}"
  raise e
end
