FROM ruby:3.2.2 AS finder

WORKDIR /app

COPY . .

RUN bundle install

CMD ["bundle", "exec", "ruby", "finder.rb"]