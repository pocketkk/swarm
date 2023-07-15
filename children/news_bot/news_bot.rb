# news_bot.rb
begin
  require 'news-api'
  require_relative 'nanny/lib/nanny'

  LOG_PATH = '/app/logs/news_bot_'

  class NewsBot < Nanny::NannyBot

    subscribe_to_channel ENV['CHANNEL_NAME'],
      types: ENV['EVENT_TYPES'].split(',').map(&:to_sym),
      callback: :process_event

    def initialize
      @newsapi = News.new(ENV['NEWS_API_KEY'])

      super
    end

    private

    def process_event(event)
      tell_mother('Processing event...')
      tell_mother("Event: #{event}")

      if event['message'].split(',')[0] == 'today'
        news = @newsapi.get_top_headlines(sources: 'bbc-news')
      else
        args = event['message'].split(',')
        query = args.select { |arg| arg.start_with?('q') }.first.split('=')[1]
        #sources = args.select { |arg| arg.start_with?('s') }.first.split('=')[1].split('|')
        from = args.select { |arg| arg.start_with?('f') }.first.split('=')[1]
        to = args.select { |arg| arg.start_with?('t') }.first.split('=')[1]
        language = 'en'
        domains = args.select { |arg| arg.start_with?('d') }.first.split('=')[1].split('|')
        exclude_domains = args.select { |arg| arg.start_with?('ed') }.first.split('=')[1].split('|')
        page_size = args.select { |arg| arg.start_with?('ps') }.first.split('=')[1]
        page = args.select { |arg| arg.start_with?('p') }.first.split('=')[1]

        news = @newsapi.get_everything(q: query, from: from, to: to, sortBy: 'popularity')
      end

      tell_mother("News: #{news}")

      news_string = "News:\n* "
      news_string += news.map { |article| article.title }.join("\n* ")

      publish_response(news_string)
    rescue => e
      tell_mother("Error: #{e.backtrace.join("\n")}")
      tell_mother("Error: #{e.message}")
    end

    def publish_response(news)
      result = publish(channel: 'events', message: { type: :agent_input, agent: ENV['CHANNEL_NAME'], message: news}.to_json)
      tell_mother("Published news: #{news}, Publish result: #{result}")

      news
    end
  end

  NewsBot.new.run
rescue => e
  Logger.new(LOG_PATH).error(e.message)
  Logger.new(LOG_PATH).error(e.backtrace.join("\n"))
  Logger.new(LOG_PATH).info("Rescue me please!, waiting...")

  loop { sleep 100 }
end
