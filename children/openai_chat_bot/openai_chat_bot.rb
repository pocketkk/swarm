# openai_chat_bot.rb

require 'net/http'
require 'uri'
require 'json'

def get_chat(message, api_key=nil)
  uri = URI("https://api.openai.com/v1/chat/completions")

  key = api_key.nil? ? ENV['OPENAI_API_KEY'] : api_key

  request = Net::HTTP::Post.new(uri)
  request["Authorization"] = "Bearer #{key}"
  request["Content-Type"] = "application/json"
  request.body = JSON.dump({
    "model" => "gpt-3.5-turbo",
    "messages" => [
      {"role" => "user", "content" => message}
    ],
    "temperature" => 0.5
  })

  response = Net::HTTP.start(uri.hostname, uri.port, :use_ssl => uri.scheme == 'https') do |http|
    http.request(request)
  end

  puts JSON.parse(response.body)

  JSON.parse(response.body)['choices'].first['message']['content'].strip
rescue => e
  puts e
  raise e
end

message = ARGV[0]
puts message
puts get_chat(ARGV[0], ARGV[1])





