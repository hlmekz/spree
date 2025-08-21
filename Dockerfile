# Multi-stage build for Spree Commerce
FROM ruby:3.3.0-alpine AS builder

# Install system dependencies
RUN apk add --no-cache \
    build-base \
    postgresql-dev \
    nodejs \
    npm \
    yarn \
    git \
    imagemagick \
    vips-dev \
    tzdata

# Set working directory
WORKDIR /app

# Copy Gemfiles
COPY Gemfile Gemfile.lock common_spree_dependencies.rb ./
COPY *.gemspec ./

# Copy all gem directories
COPY core/ ./core/
COPY api/ ./api/
COPY admin/ ./admin/
COPY storefront/ ./storefront/
COPY emails/ ./emails/
COPY sample/ ./sample/
COPY cli/ ./cli/
COPY lib/ ./lib/

# Install gems
RUN bundle config set --local deployment 'true' && \
    bundle config set --local without 'development test' && \
    bundle install --jobs 4 --retry 3

# Copy application code
COPY . .

# Precompile assets (if any)
RUN if [ -f "bin/rails" ]; then \
      RAILS_ENV=production \
      SECRET_KEY_BASE=dummy \
      bundle exec rails assets:precompile; \
    fi

# Production stage
FROM ruby:3.3.0-alpine AS production

# Install runtime dependencies
RUN apk add --no-cache \
    postgresql-client \
    imagemagick \
    vips \
    tzdata \
    curl

# Create app user
RUN addgroup -g 1000 -S app && \
    adduser -u 1000 -S app -G app

# Set working directory
WORKDIR /app

# Copy gems from builder
COPY --from=builder /usr/local/bundle /usr/local/bundle

# Copy application
COPY --from=builder --chown=app:app /app /app

# Make start script executable
RUN chmod +x bin/start-production

# Ensure start-production script exists and is executable
RUN ls -la bin/ && test -f bin/start-production

# Switch to app user
USER app

# Expose port
EXPOSE 3000

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:3000/health || exit 1

# Start command
CMD ["./bin/start-production"]