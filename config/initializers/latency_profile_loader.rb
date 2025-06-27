# frozen_string_literal: true

# config/initializers/latency_profile_loader.rb
LATENCY_PROFILE = {}.freeze

begin
  config_file = Rails.root.join('config', 'latency_profile.yml')
  if File.exist?(config_file)
    yaml_content = YAML.load_file(config_file)
    # Ensure all keys are symbols for consistent access
    LATENCY_PROFILE.merge!(yaml_content.deep_symbolize_keys)
    Rails.logger.info "Latency profile loaded successfully: #{LATENCY_PROFILE.inspect}"

    # Validate required keys
    required_keys = %i[max p99 p95 p90 p75 p50]
    missing_keys = required_keys.reject { |key| LATENCY_PROFILE.key?(key) }

    if missing_keys.any?
      Rails.logger.error "Latency profile configuration is missing required keys: #{missing_keys.join(', ')}. Using default empty profile."
      LATENCY_PROFILE.clear # Or set to a default safe profile
    end

  else
    Rails.logger.warn "Latency profile configuration file not found: #{config_file}. Using default empty profile."
  end
rescue StandardError => e
  Rails.logger.error "Error loading latency profile: #{e.message}. Using default empty profile."
  LATENCY_PROFILE.clear # Or set to a default safe profile
end

# Freeze the configuration to prevent runtime modifications
LATENCY_PROFILE.freeze
