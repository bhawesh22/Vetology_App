# syntax=docker/dockerfile:1

FROM nginx:1.27-alpine

# Remove default nginx static content
RUN rm /usr/share/nginx/html/index.html

# Copy HTML template (uses ${WEBTEXT} placeholder)
COPY index.html /usr/share/nginx/html/index.html.template

# Set default value for WEBTEXT
ENV WEBTEXT="Hello World!"

# Allow nginx (non-root, UID 101) to write to html dir and run on port 80
RUN chown -R nginx:nginx /usr/share/nginx/html && \
    chown -R nginx:nginx /var/cache/nginx && \
    chown -R nginx:nginx /var/log/nginx && \
    touch /var/run/nginx.pid && \
    chown nginx:nginx /var/run/nginx.pid

USER nginx

EXPOSE 80

HEALTHCHECK --interval=30s --timeout=5s --start-period=5s --retries=3 \
  CMD wget -qO- http://localhost:80 || exit 1

# envsubst replaces ${WEBTEXT} in template at container start, then nginx runs
CMD ["/bin/sh", "-c", "envsubst < /usr/share/nginx/html/index.html.template > /usr/share/nginx/html/index.html && nginx -g 'daemon off;'"]