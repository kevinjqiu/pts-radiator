FROM frvi/ruby
MAINTAINER kevin.qiu@points.com

RUN gem install bundle
RUN mkdir /app
ADD config.ru /app/config.ru
ADD assets /app/assets
ADD dashboards /app/dashboards
ADD Gemfile /app/Gemfile
ADD jobs /app/jobs
ADD public /app/public
ADD widgets /app/widgets
COPY run.sh /

RUN cd /app && bundle install

VOLUME ["/app/config"]

ENV PORT 3030
EXPOSE $PORT
WORKDIR /app
CMD ["/run.sh"]
