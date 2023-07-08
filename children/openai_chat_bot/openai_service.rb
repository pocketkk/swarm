# openai_service.rb
require 'net/http'
require 'uri'
require 'json'

class OpenAIService
  API_ENDPOINT = 'https://api.openai.com/v1/chat/completions'
  MODEL = 'gpt-3.5-turbo'
  CONTENT_TYPE = 'application/json'

  def initialize(api_key)
    @api_key = api_key
  end

  def chat(message)
    uri = URI(API_ENDPOINT)
    request = create_request(uri, message)
    response = send_request(uri, request)
    parse_response(response)
  end

  private

  def create_request(uri, message)
    request = Net::HTTP::Post.new(uri)
    request['Authorization'] = "Bearer #{@api_key}"
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
end
