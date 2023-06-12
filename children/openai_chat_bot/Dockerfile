# Dockerfile

FROM ruby:3.0.2

WORKDIR /app

COPY . /app

RUN bundle install

CMD ["ruby", "openai_chat_bot.rb"]
