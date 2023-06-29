# logger.rb
require 'logger'

class BotLogger
  LOG_PATH = '/app/logs/open_ai_chatbot_'

  def initialize
    @logger = Logger.new(LOG_PATH + timestamp + '.log')
  end

  def info(message, include_stdout: true)
    @logger.info(message)
    puts message if include_stdout
  end

  def error(message, include_stdout: true)
    @logger.error(message)
    puts "Error: #{message}" if include_stdout
  end

  def timestamp
    Time.now.strftime('%Y%m%d')
  end
end
