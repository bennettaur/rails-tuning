# spec/requests/latency_spec.rb
require 'rails_helper'

RSpec.describe 'LatencyController API', type: :request do
  let(:valid_profile) do
    {
      max: 3000,
      p99: 200,
      p95: 100,
      p90: 75,
      p75: 50,
      p50: 25
    }
  end

  let(:profile_with_equal_percentiles) do
    {
      max: 3000,
      p99: 200,
      p95: 200, # p95 == p99
      p90: 75,
      p75: 75, # p75 == p90
      p50: 25
    }
  end

  let(:profile_with_zero_value) do
    # Using .dup to avoid modifying the original valid_profile if it's used elsewhere by reference
    valid_profile.dup.merge!(p50: 0, p75: 0) # p50 is 0, p75 is 0. Need to ensure other values are consistent if this were a real profile.
                                             # For this test, we primarily care about p50 and p75.
                                             # A fully consistent profile would be: p50=0, p75=0, p90=75, p95=100, p99=200, max=3000
                                             # Let's make it consistent for the test:
    {
      max: 3000,
      p99: 200,
      p95: 100,
      p90: 75,
      p75: 0, # p75 is 0
      p50: 0  # p50 is 0
    }
  end

  let(:invalid_order_profile) do
    {
      max: 3000,
      p99: 200,
      p95: 100,
      p90: 150, # p90 > p95 - invalid order
      p75: 50,
      p50: 25
    }
  end

  let(:missing_keys_profile) do
    {
      max: 3000,
      p99: 200
      # p95, p90, p75, p50 are missing
    }
  end

  # Helper to stub the LATENCY_PROFILE constant for tests
  def stub_latency_profile(profile)
    stub_const("LATENCY_PROFILE", profile.deep_symbolize_keys)
  end

  describe 'GET /simulate_latency' do
    context 'with a valid latency profile' do
      before { stub_latency_profile(valid_profile) }

      it 'returns a successful response and expected JSON structure' do
        # Allow original rand by default
        allow_any_instance_of(LatencyController).to receive(:rand).and_call_original
        # Stub specific call for random_percent
        allow_any_instance_of(LatencyController).to receive(:rand).with(1..100).and_return(50)

        get '/simulate_latency'
        expect(response).to have_http_status(:ok)
        json_response = JSON.parse(response.body).deep_symbolize_keys

        expect(json_response).to include(
          :message,
          :random_draw_percentile,
          :target_latency_band_label,
          :conceptual_latency_range_ms,
          :requested_sleep_ms,
          :actual_slept_ms
        )
        expect(json_response[:message]).to eq("Simulated latency based on profile.")
      end

      context 'testing specific percentile bands' do
        it 'correctly simulates for the "<=p50" band' do
          allow_any_instance_of(LatencyController).to receive(:rand).and_call_original
          allow_any_instance_of(LatencyController).to receive(:rand).with(1..100).and_return(25)

          get '/simulate_latency'
          json_response = JSON.parse(response.body).deep_symbolize_keys

          expect(json_response[:random_draw_percentile]).to eq(25)
          expect(json_response[:target_latency_band_label]).to eq('<=p50')
          expect(json_response[:conceptual_latency_range_ms]).to eq("0-#{valid_profile[:p50]}")
          expect(json_response[:requested_sleep_ms]).to be_between(0, valid_profile[:p50]).inclusive
        end

        it 'correctly simulates for the ">p50 to p75" band' do
          allow_any_instance_of(LatencyController).to receive(:rand) do |controller_instance, range_argument|
            if range_argument == (1..100)
              60 # Stubbed value for random_percent
            else
              Kernel.rand(range_argument) # Actual rand for sleep_duration_ms
            end
          end

          get '/simulate_latency'
          json_response = JSON.parse(response.body).deep_symbolize_keys

          expect(json_response[:target_latency_band_label]).to eq('>p50 to p75')
          expected_lower = valid_profile[:p50] < valid_profile[:p75] ? valid_profile[:p50] + 1 : valid_profile[:p50]
          expected_upper = valid_profile[:p75]
          expect(json_response[:conceptual_latency_range_ms]).to eq("#{expected_lower}-#{expected_upper}")
          expect(json_response[:requested_sleep_ms]).to be_between(expected_lower, expected_upper).inclusive
        end

        it 'correctly simulates for the ">p95 to p99" band' do
          allow_any_instance_of(LatencyController).to receive(:rand).and_call_original
          allow_any_instance_of(LatencyController).to receive(:rand).with(1..100).and_return(98)

          get '/simulate_latency'
          json_response = JSON.parse(response.body).deep_symbolize_keys

          expect(json_response[:target_latency_band_label]).to eq('>p95 to p99')
          expected_lower = valid_profile[:p95] < valid_profile[:p99] ? valid_profile[:p95] + 1 : valid_profile[:p95]
          expected_upper = valid_profile[:p99]
          expect(json_response[:conceptual_latency_range_ms]).to eq("#{expected_lower}-#{expected_upper}")
          expect(json_response[:requested_sleep_ms]).to be_between(expected_lower, expected_upper).inclusive
        end

        it 'correctly simulates for the ">p99 to max" band' do
          allow_any_instance_of(LatencyController).to receive(:rand).and_call_original
          allow_any_instance_of(LatencyController).to receive(:rand).with(1..100).and_return(100)

          get '/simulate_latency'
          json_response = JSON.parse(response.body).deep_symbolize_keys

          expect(json_response[:target_latency_band_label]).to eq('>p99 to max')
          expected_lower = valid_profile[:p99] < valid_profile[:max] ? valid_profile[:p99] + 1 : valid_profile[:p99]
          expected_upper = valid_profile[:max]
          expect(json_response[:conceptual_latency_range_ms]).to eq("#{expected_lower}-#{expected_upper}")
          expect(json_response[:requested_sleep_ms]).to be_between(expected_lower, expected_upper).inclusive
        end
      end
    end

    context 'with a profile having equal percentile values' do
      before { stub_latency_profile(profile_with_equal_percentiles) }

      it 'correctly simulates for ">p95 to p99" band when p95 == p99' do
        allow_any_instance_of(LatencyController).to receive(:rand).and_call_original
        allow_any_instance_of(LatencyController).to receive(:rand).with(1..100).and_return(98)

        get '/simulate_latency'
        json_response = JSON.parse(response.body).deep_symbolize_keys

        expect(json_response[:target_latency_band_label]).to eq('>p95 to p99')
        # For p95=200, p99=200: lower_bound = (200 < 200 ? 201 : 200) = 200. upper_bound = 200.
        expected_lower = profile_with_equal_percentiles[:p95]
        expected_upper = profile_with_equal_percentiles[:p99]
        expect(json_response[:conceptual_latency_range_ms]).to eq("#{expected_lower}-#{expected_upper}")
        expect(json_response[:requested_sleep_ms]).to eq(expected_lower)
      end
    end

    context 'with a profile having zero values and consistent ordering' do
      # profile_with_zero_value is p50=0, p75=0, p90=75, etc.
      before { stub_latency_profile(profile_with_zero_value) }

      it 'correctly simulates for "<=p50" band when p50 is 0' do
        allow_any_instance_of(LatencyController).to receive(:rand).and_call_original
        allow_any_instance_of(LatencyController).to receive(:rand).with(1..100).and_return(10)
        get '/simulate_latency'
        json_response = JSON.parse(response.body).deep_symbolize_keys
        expect(json_response[:conceptual_latency_range_ms]).to eq("0-0") # p50 is 0
        expect(json_response[:requested_sleep_ms]).to eq(0)
      end

      # For ">p50 to p75" band: p50=0, p75=0.
      # lower_bound = (p50 < p75 ? p50+1 : p50) = (0 < 0 ? 1 : 0) = 0. upper_bound = 0.
      it 'correctly simulates for ">p50 to p75" band when p50=0 and p75=0' do
        allow_any_instance_of(LatencyController).to receive(:rand).and_call_original
        allow_any_instance_of(LatencyController).to receive(:rand).with(1..100).and_return(60)
        get '/simulate_latency'
        json_response = JSON.parse(response.body).deep_symbolize_keys
        expect(json_response[:conceptual_latency_range_ms]).to eq("0-0")
        expect(json_response[:requested_sleep_ms]).to eq(0)
      end
    end

    context 'error handling for profile issues' do
      it 'returns an error when latency profile is empty' do
        stub_latency_profile({})
        get '/simulate_latency'
        expect(response).to have_http_status(:internal_server_error)
        json_response = JSON.parse(response.body).deep_symbolize_keys
        expect(json_response[:error]).to include("Latency profile not loaded or is empty")
      end

      it 'returns an error when latency profile has missing keys' do
        stub_latency_profile(missing_keys_profile)
        get '/simulate_latency'
        expect(response).to have_http_status(:internal_server_error)
        json_response = JSON.parse(response.body).deep_symbolize_keys
        expect(json_response[:error]).to include("Latency profile is missing, or has invalid (non-numeric) values for keys:")
        expect(json_response[:error]).to include("p95")
        expect(json_response[:error]).to include("p50")
      end

      it 'returns an error when latency profile has incorrectly ordered keys' do
        stub_latency_profile(invalid_order_profile)
        get '/simulate_latency'
        expect(response).to have_http_status(:internal_server_error)
        json_response = JSON.parse(response.body).deep_symbolize_keys
        expect(json_response[:error]).to include("Latency profile values are not logically ordered")
        expect(json_response[:error]).to include("p90=#{invalid_order_profile[:p90]}")
        expect(json_response[:error]).to include("p95=#{invalid_order_profile[:p95]}")
      end
    end
  end
end
