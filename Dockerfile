# syntax=docker/dockerfile:1

FROM nginx:1.27-alpine

# Remove default nginx static content
RUN rm /usr/share/nginx/html/index.html

# Copy HTML template (uses ${WEBTEXT} placeholder)
COPY index.html /usr/share/nginx/html/index.html.template

# Set default value for WEBTEXT
ENV WEBTEXT="Hello World!"

EXPOSE 80

# envsubst replaces ${WEBTEXT} in template at container start, then nginx runs
CMD ["/bin/sh", "-c", "envsubst < /usr/share/nginx/html/index.html.template > /usr/share/nginx/html/index.html && nginx -g 'daemon off;'"]
