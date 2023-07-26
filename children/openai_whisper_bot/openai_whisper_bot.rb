# openai_transcription_bot.rb
begin
  require 'faraday'
  require 'faraday_middleware'
  require_relative 'nanny/lib/nanny'

  LOG_PATH = '/app/logs/openai_whisper_bot_'

  class OpenAIWhisperBot < Nanny::NannyBot

    subscribe_to_channel ENV['CHANNEL_NAME'],
      types: ENV['EVENT_TYPES'].split(',').map(&:to_sym),
      callback: :process_event

    private

    def process_event(event)
      tell_mother('Processing event ...')

      file_path = event['message']

      response = transcribe_audio(file_path)

      publish_response(response)
    end

    def transcribe_audio(file_path)
      conn = Faraday.new(url: 'https://api.openai.com') do |f|
        f.request :multipart
        f.request :url_encoded
        f.adapter :net_http
      end

      payload = { file: Faraday::UploadIO.new(file_path, 'audio/mp3'), model: 'whisper-1' }

      response = conn.post do |req|
        req.url '/v1/audio/transcriptions'
        req.headers['Authorization'] = "Bearer #{ENV['OPENAI_API_KEY']}"
        req.headers['Content-Type'] = 'multipart/form-data'
        req.body = payload
      end

      JSON.parse(response.body)['text']
    end

    def publish_response(response)
      result = publish(channel: 'events', message: { type: :agent_input, agent: 'openai_transcription_bot', message: response}.to_json)

      tell_mother("Published message: #{response}, Publish result: #{result}")

      response
    end
  end

  OpenAIWhisperBot.new.run
rescue => e
  Logger.new(LOG_PATH).error(e.message)
  Logger.new(LOG_PATH).error(e.backtrace.join("\n"))
  Logger.new(LOG_PATH).info("Rescue me please!, waiting ...")

  loop { sleep 100 }
end
