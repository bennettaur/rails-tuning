# frozen_string_literal: true

# Service class to simulate latency based on a given profile.
class LatencySimulator
  def initialize(profile)
    @profile = profile
  end

  def simulate
    raise 'Latency profile not loaded or is empty. Check server logs.' if @profile.blank?

    validate_profile(@profile)

    random_percent = rand(1..100)
    band = calculate_latency_band(@profile, random_percent)
    sleep_duration_ms = calculate_sleep_duration(band[:lower], band[:upper], band[:label])
    sleep_duration_ms = [0, sleep_duration_ms].max
    actual_slept_time_ms = perform_sleep(sleep_duration_ms)

    {
      message: 'Simulated latency based on profile.',
      random_draw_percentile: random_percent,
      target_latency_band_label: band[:label],
      calculated_latency_target_ms: sleep_duration_ms,
      conceptual_latency_range_ms: "#{band[:lower]}-#{band[:upper]}",
      requested_sleep_ms: sleep_duration_ms,
      actual_slept_ms: actual_slept_time_ms
    }
  end

  private

  # rubocop:disable Metrics/AbcSize
  # rubocop:disable Metrics/CyclomaticComplexity
  def validate_profile(profile)
    required_keys = %i[max p99 p95 p90 p75 p50]
    missing_or_invalid_keys = required_keys.reject do |key|
      profile.key?(key) && profile[key].is_a?(Numeric)
    end
    if missing_or_invalid_keys.any?
      raise 'Latency profile is missing, or has invalid (non-numeric) values for keys: ' \
            "#{missing_or_invalid_keys.join(', ')}"
    end
    max_latency = profile[:max].to_i
    p99_val = profile[:p99].to_i
    p95_val = profile[:p95].to_i
    p90_val = profile[:p90].to_i
    p75_val = profile[:p75].to_i
    p50_val = profile[:p50].to_i
    unless p75_val.between?(p50_val, p90_val) && p90_val <= p95_val &&
           p95_val <= p99_val && p99_val <= max_latency
      raise 'Latency profile values are not logically ordered (p50 <= p75 <= p90 <= p95 <= p99 <= max). ' \
            "Current values: p50=#{p50_val}, p75=#{p75_val}, p90=#{p90_val}, " \
            "p95=#{p95_val}, p99=#{p99_val}, max=#{max_latency}."
    end
    nil
  end
  # rubocop:enable Metrics/AbcSize
  # rubocop:enable Metrics/CyclomaticComplexity

  # rubocop:disable Metrics/AbcSize
  # rubocop:disable Metrics/CyclomaticComplexity
  def calculate_latency_band(profile, random_percent)
    max_latency = profile[:max].to_i
    p99_val = profile[:p99].to_i
    p95_val = profile[:p95].to_i
    p90_val = profile[:p90].to_i
    p75_val = profile[:p75].to_i
    p50_val = profile[:p50].to_i
    case random_percent
    when 100
      lower = p99_val < max_latency ? p99_val + 1 : p99_val
      upper = max_latency
      label = '>p99 to max'
    when 96..99
      lower = p95_val < p99_val ? p95_val + 1 : p95_val
      upper = p99_val
      label = '>p95 to p99'
    when 91..95
      lower = p90_val < p95_val ? p90_val + 1 : p90_val
      upper = p95_val
      label = '>p90 to p95'
    when 76..90
      lower = p75_val < p90_val ? p75_val + 1 : p75_val
      upper = p90_val
      label = '>p75 to p90'
    when 51..75
      lower = p50_val < p75_val ? p50_val + 1 : p50_val
      upper = p75_val
      label = '>p50 to p75'
    else
      lower = 0
      upper = p50_val
      label = '<=p50'
    end
    { lower: lower, upper: upper, label: label }
  end
  # rubocop:enable Metrics/AbcSize
  # rubocop:enable Metrics/CyclomaticComplexity

  def calculate_sleep_duration(lower, upper, label)
    if lower > upper
      Rails.logger.error(
        "Critical: Calculated lower_bound (#{lower}) > calculated_upper_bound (#{upper}) for #{label}. " \
        'This indicates a flaw in bound calculation or unhandled profile edge case. ' \
        "Defaulting sleep to calculated_upper_bound (#{upper}ms)."
      )
      upper
    elsif lower == upper
      lower
    else
      rand(lower..upper)
    end
  end

  def perform_sleep(sleep_duration_ms)
    return 0 unless sleep_duration_ms.positive?

    sleep_duration_seconds = sleep_duration_ms / 1000.0
    start_time = Time.zone.now
    sleep(sleep_duration_seconds)
    ((Time.zone.now - start_time) * 1000).round(2)
  end
end
