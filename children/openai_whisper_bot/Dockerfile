# Dockerfile

FROM ruby:3.0.2

WORKDIR /app

COPY . /app

RUN bundle install
RUN mkdir /app/logs

CMD ["ruby", "openai_whisper_bot.rb"]

VOLUME [ "/app/logs" ]
