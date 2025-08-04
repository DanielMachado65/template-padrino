FROM ruby:3.2.9-alpine3.21

WORKDIR /app

COPY Gemfile Gemfile.lock ./
RUN bundle install

COPY . .

EXPOSE 4567
CMD ["bundle", "exec", "rackup", "-p", "4567", "-o", "0.0.0.0"]