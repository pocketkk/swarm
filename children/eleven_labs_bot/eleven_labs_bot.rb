# eleven_labs_bot.rb
begin
  require_relative 'nanny/lib/nanny'
  require 'open3'

  LOG_PATH = '/app/logs/eleven_labs_'

  class TextToSpeechService
    API_ENDPOINT = 'https://api.elevenlabs.io/v1/text-to-speech/'

    def initialize(api_key, voice_id, nanny)
      @nanny = nanny
      @api_key = api_key
      @voice_id = voice_id
    end

    def convert_text_to_speech(text)
      uri = URI(API_ENDPOINT + @voice_id + '/stream')
      @nanny.tell_mother("URI: #{uri}")

      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true

      request = Net::HTTP::Post.new(uri.request_uri)
      request["xi-api-key"] = @api_key
      request["Content-Type"] = "application/json"
      request.body = {
        text: text,
        model_id: "eleven_monolingual_v1",
        voice_settings: {
          stability: 0,
          similarity_boost: 0,
          style: 0.5,
          use_speaker_boost: true
        }
      }.to_json

      http.request(request) do |response|
        if response.code.to_i == 200
          Open3.popen2('ffplay -nodisp -autoexit -i pipe:0') do |stdin, stdout, thread|
            response.read_body do |chunk|
              stdin.write(chunk)
            end
            stdin.close
            thread.join.value
          end
          'Audio played.'
        else
          @nanny.tell_mother("Error: #{response.code} - #{response.message}")
          'Error converting text to speech.'
        end
      end
    end
  end

  class ElevenLabsBot < Nanny::NannyBot

    subscribe_to_channel ENV['CHANNEL_NAME'],
      types: ENV['EVENT_TYPES'].split(',').map(&:to_sym),
      callback: :process_event

    private

    def process_event(event)
      tell_mother('Processing event ...')

      text = event['message']
      tell_mother("Text to speech: #{text}")
      tell_mother("ENV: #{ENV['ELEVEN_LABS_API_KEY']}, #{ENV['VOICE']}")

      response = TextToSpeechService.new(ENV['ELEVEN_LABS_API_KEY'], ENV['VOICE'], @nanny).convert_text_to_speech(text)
      publish_response(response)
    rescue => e
      tell_mother("Error: #{e.backtrace.join("\n")}")
      tell_mother("Error: #{e.message}")
    end

    def publish_response(response)
      tell_mother("Playing response: #{response}")

      #output = response.gsub('.mp3','.wav')
      #system("ffmpeg -i #{response} #{output}")
      #system("paplay #{output}")

      result = publish(channel: 'events', message: { type: :agent_input, agent: ENV['CHANNEL_NAME'], message: response }.to_json)

      tell_mother("Published message: #{response}, Publish result: #{result}")

      response
    end
  end

  ElevenLabsBot.new.run
rescue => e
  Logger.new(LOG_PATH).error(e.message)
  Logger.new(LOG_PATH).error(e.backtrace.join("\n"))
  Logger.new(LOG_PATH).info("Rescue me please!, waiting ...")

  loop { sleep 100 }
end
