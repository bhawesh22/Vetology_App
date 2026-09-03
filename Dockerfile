# syntax=docker/dockerfile:1

FROM nginx:1.27-alpine

# Remove default nginx static content
RUN rm /usr/share/nginx/html/index.html

# Copy HTML template
COPY index.html /usr/share/nginx/html/index.html.template

# Set default value for WEBTEXT
ENV WEBTEXT="Hello World!"

# Allow nginx (non-root, UID 101) to write required directories
RUN chown -R nginx:nginx /usr/share/nginx/html && \
    chown -R nginx:nginx /var/cache/nginx && \
    chown -R nginx:nginx /var/log/nginx && \
    touch /var/run/nginx.pid && \
    chown nginx:nginx /var/run/nginx.pid

USER 101

EXPOSE 80

HEALTHCHECK --interval=30s --timeout=5s --start-period=5s --retries=3 \
  CMD ["wget", "-qO-", "http://localhost:80"]

# Copy startup script
COPY start.sh /start.sh

RUN chmod +x /start.sh

CMD ["/start.sh"]
