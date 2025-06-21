# app/controllers/latency_controller.rb
class LatencyController < ApplicationController
  def simulate
    if LATENCY_PROFILE.nil? || LATENCY_PROFILE.empty?
      render json: { error: 'Latency profile not loaded or is empty. Check server logs.' }, status: :internal_server_error
      return
    end

    required_keys = [:max, :p99, :p95, :p90, :p75, :p50]
    # Check if all keys are present and are numeric
    missing_or_invalid_keys = required_keys.reject do |key|
      LATENCY_PROFILE.key?(key) && LATENCY_PROFILE[key].is_a?(Numeric)
    end

    if missing_or_invalid_keys.any?
      render json: { error: "Latency profile is missing, or has invalid (non-numeric) values for keys: #{missing_or_invalid_keys.join(', ')}" }, status: :internal_server_error
      return
    end

    max_latency = LATENCY_PROFILE[:max].to_i
    p99_val = LATENCY_PROFILE[:p99].to_i
    p95_val = LATENCY_PROFILE[:p95].to_i
    p90_val = LATENCY_PROFILE[:p90].to_i
    p75_val = LATENCY_PROFILE[:p75].to_i
    p50_val = LATENCY_PROFILE[:p50].to_i

    # Validate that percentile values are logically ordered (e.g., p50 <= p75 <= ... <= max)
    unless p50_val <= p75_val &&            p75_val <= p90_val &&            p90_val <= p95_val &&            p95_val <= p99_val &&            p99_val <= max_latency
      error_message = "Latency profile values are not logically ordered (p50 <= p75 <= p90 <= p95 <= p99 <= max). " +
                      "Current values: p50=#{p50_val}, p75=#{p75_val}, p90=#{p90_val}, p95=#{p95_val}, p99=#{p99_val}, max=#{max_latency}."
      render json: { error: error_message }, status: :internal_server_error
      return
    end

    random_percent = rand(1..100) # Random number between 1 and 100 inclusive

    calculated_lower_bound = 0
    calculated_upper_bound = 0
    percentile_category_label = "" # Descriptive label for the category

    if random_percent == 100 # Top 1% :: (p99_val, max_latency]
      calculated_lower_bound = p99_val < max_latency ? p99_val + 1 : p99_val # if p99=max, range is just p99. else p99+1 to max
      calculated_upper_bound = max_latency
      percentile_category_label = ">p99 to max"
    elsif random_percent >= 96 # Next 4% (96-99) :: (p95_val, p99_val]
      calculated_lower_bound = p95_val < p99_val ? p95_val + 1 : p95_val
      calculated_upper_bound = p99_val
      percentile_category_label = ">p95 to p99"
    elsif random_percent >= 91 # Next 5% (91-95) :: (p90_val, p95_val]
      calculated_lower_bound = p90_val < p95_val ? p90_val + 1 : p90_val
      calculated_upper_bound = p95_val
      percentile_category_label = ">p90 to p95"
    elsif random_percent >= 76 # Next 15% (76-90) :: (p75_val, p90_val]
      calculated_lower_bound = p75_val < p90_val ? p75_val + 1 : p75_val
      calculated_upper_bound = p90_val
      percentile_category_label = ">p75 to p90"
    elsif random_percent >= 51 # Next 25% (51-75) :: (p50_val, p75_val]
      calculated_lower_bound = p50_val < p75_val ? p50_val + 1 : p50_val
      calculated_upper_bound = p75_val
      percentile_category_label = ">p50 to p75"
    else # Bottom 50% (1-50) :: [0, p50_val]
      calculated_lower_bound = 0
      calculated_upper_bound = p50_val
      percentile_category_label = "<=p50"
    end

    sleep_duration_ms = 0
    # If calculated_lower_bound > calculated_upper_bound, it implies an issue.
    # This can happen if pX_val + 1 > pY_val because pX_val is equal to or just under pY_val.
    # The ternary operator `pX < pY ? pX + 1 : pX` for lower_bound assignment handles the equality case.
    # So, lower_bound > upper_bound should now only occur if there's a misconfig like p75_val > p90_val,
    # which is caught by the initial validation.
    # However, as a safeguard or if profile values are identical (e.g. p75_val = 20, p90_val = 20),
    # then lower_bound (e.g. 20 for p75<p90?p75+1:p75) will equal upper_bound (e.g. 20).
    if calculated_lower_bound > calculated_upper_bound
      # This situation should ideally be prevented by the initial percentile order validation
      # and the careful setting of calculated_lower_bound (using ternary for X+1).
      # If it still occurs, it implies an edge case or misconfiguration not fully handled.
      # Defaulting to upper_bound of the band is a reasonable fallback.
      sleep_duration_ms = calculated_upper_bound
      Rails.logger.error "Critical: Calculated lower_bound (#{calculated_lower_bound}) > calculated_upper_bound (#{calculated_upper_bound}) for #{percentile_category_label}. This indicates a flaw in bound calculation or unhandled profile edge case. Defaulting sleep to calculated_upper_bound (#{sleep_duration_ms}ms)."
    elsif calculated_lower_bound == calculated_upper_bound
      sleep_duration_ms = calculated_lower_bound
    else
      sleep_duration_ms = rand(calculated_lower_bound..calculated_upper_bound)
    end

    sleep_duration_ms = [0, sleep_duration_ms].max

    actual_slept_time_ms = 0
    if sleep_duration_ms > 0
      sleep_duration_seconds = sleep_duration_ms / 1000.0
      start_time = Time.now
      sleep(sleep_duration_seconds)
      actual_slept_time_ms = ((Time.now - start_time) * 1000).round(2)
    end

    response_details = {
      message: "Simulated latency based on profile.",
      random_draw_percentile: random_percent,
      target_latency_band_label: percentile_category_label,
      # Providing the exact range used for rand() or the determined value
      calculated_latency_target_ms: sleep_duration_ms,
      # The conceptual range based on profile values for this band
      conceptual_latency_range_ms: "#{calculated_lower_bound}-#{calculated_upper_bound}",
      requested_sleep_ms: sleep_duration_ms, # Duplicates calculated_latency_target_ms but often kept for clarity
      actual_slept_ms: actual_slept_time_ms
    }
    render json: response_details, status: :ok
  end
end
