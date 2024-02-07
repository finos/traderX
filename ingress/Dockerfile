FROM nginx

EXPOSE 8080
ARG NGINX_HOST="localhost"
ENV NGINX_HOST=$NGINX_HOST

COPY nginx.traderx.conf.template /etc/nginx/conf.d/nginx.traderx.conf.template

RUN envsubst < /etc/nginx/conf.d/nginx.traderx.conf.template > /etc/nginx/conf.d/default.conf
