FROM ruby:3.2.2-alpine
# skip installing gem documentation

RUN apk add --no-cache build-base gcc libcurl

ADD Gemfile Gemfile.lock .

RUN bundle install

ADD . .

ENTRYPOINT ruby run.rb
CMD -s