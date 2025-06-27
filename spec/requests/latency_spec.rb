# frozen_string_literal: true

# spec/requests/latency_spec.rb
require 'rails_helper'

RSpec.describe 'LatencyController API' do
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
    stub_const('LATENCY_PROFILE', profile.deep_symbolize_keys)
  end

  # Helper to stub rand on the controller instance
  def stub_controller_rand(controller, value)
    allow(controller).to receive(:rand).with(1..100).and_return(value)
    allow(controller).to receive(:rand).and_call_original
  end

  describe 'GET /simulate_latency' do
    context 'when using a valid latency profile' do
      before { stub_latency_profile(valid_profile) }

      it 'returns a successful response and expected JSON structure' do
        get '/simulate_latency'
        json_response = response.parsed_body.deep_symbolize_keys
        expect(response).to have_http_status(:ok)
        expect(json_response).to include(
          :message,
          :random_draw_percentile,
          :target_latency_band_label,
          :conceptual_latency_range_ms,
          :requested_sleep_ms,
          :actual_slept_ms
        )
        expect(json_response[:message]).to eq('Simulated latency based on profile.')
      end

      context 'when testing specific percentile bands' do
        it 'simulates for the "<=p50" band' do
          controller = LatencyController.new
          stub_controller_rand(controller, 25)
          allow(LatencyController).to receive(:new).and_return(controller)
          get '/simulate_latency'
          json_response = response.parsed_body.deep_symbolize_keys
          expect(json_response[:random_draw_percentile]).to eq(25)
          expect(json_response[:target_latency_band_label]).to eq('<=p50')
          expect(json_response[:conceptual_latency_range_ms])
            .to eq("0-#{valid_profile[:p50]}")
          expect(json_response[:requested_sleep_ms])
            .to be_between(0, valid_profile[:p50]).inclusive
        end

        it 'simulates for the ">p50 to p75" band' do
          controller = LatencyController.new
          stub_controller_rand(controller, 60)
          allow(LatencyController).to receive(:new).and_return(controller)
          get '/simulate_latency'
          json_response = response.parsed_body.deep_symbolize_keys
          expect(json_response[:target_latency_band_label]).to eq('>p50 to p75')
          expected_lower = valid_profile[:p50] < valid_profile[:p75] ? valid_profile[:p50] + 1 : valid_profile[:p50]
          expected_upper = valid_profile[:p75]
          expect(json_response[:conceptual_latency_range_ms])
            .to eq("#{expected_lower}-#{expected_upper}")
          expect(json_response[:requested_sleep_ms])
            .to be_between(expected_lower, expected_upper).inclusive
        end

        it 'simulates for the ">p95 to p99" band' do
          controller = LatencyController.new
          stub_controller_rand(controller, 98)
          allow(LatencyController).to receive(:new).and_return(controller)
          get '/simulate_latency'
          json_response = response.parsed_body.deep_symbolize_keys
          expect(json_response[:target_latency_band_label]).to eq('>p95 to p99')
          expected_lower = valid_profile[:p95] < valid_profile[:p99] ? valid_profile[:p95] + 1 : valid_profile[:p95]
          expected_upper = valid_profile[:p99]
          expect(json_response[:conceptual_latency_range_ms])
            .to eq("#{expected_lower}-#{expected_upper}")
          expect(json_response[:requested_sleep_ms])
            .to be_between(expected_lower, expected_upper).inclusive
        end

        it 'simulates for the ">p99 to max" band' do
          controller = LatencyController.new
          stub_controller_rand(controller, 100)
          allow(LatencyController).to receive(:new).and_return(controller)
          get '/simulate_latency'
          json_response = response.parsed_body.deep_symbolize_keys
          expect(json_response[:target_latency_band_label]).to eq('>p99 to max')
          expected_lower = valid_profile[:p99] < valid_profile[:max] ? valid_profile[:p99] + 1 : valid_profile[:p99]
          expected_upper = valid_profile[:max]
          expect(json_response[:conceptual_latency_range_ms])
            .to eq("#{expected_lower}-#{expected_upper}")
          expect(json_response[:requested_sleep_ms])
            .to be_between(expected_lower, expected_upper).inclusive
        end
      end
    end

    context 'when using a profile with equal percentile values' do
      before { stub_latency_profile(profile_with_equal_percentiles) }

      it 'simulates for ">p95 to p99" band when p95 == p99' do
        controller = LatencyController.new
        stub_controller_rand(controller, 98)
        allow(LatencyController).to receive(:new).and_return(controller)
        get '/simulate_latency'
        json_response = response.parsed_body.deep_symbolize_keys
        expect(json_response[:target_latency_band_label]).to eq('>p95 to p99')
        expected_lower = profile_with_equal_percentiles[:p95]
        expected_upper = profile_with_equal_percentiles[:p99]
        expect(json_response[:conceptual_latency_range_ms])
          .to eq("#{expected_lower}-#{expected_upper}")
        expect(json_response[:requested_sleep_ms]).to eq(expected_lower)
      end
    end

    context 'when using a profile with zero values and consistent ordering' do
      before { stub_latency_profile(profile_with_zero_value) }

      it 'simulates for "<=p50" band when p50 is 0' do
        controller = LatencyController.new
        stub_controller_rand(controller, 10)
        allow(LatencyController).to receive(:new).and_return(controller)
        get '/simulate_latency'
        json_response = response.parsed_body.deep_symbolize_keys
        expect(json_response[:conceptual_latency_range_ms]).to eq('0-0')
        expect(json_response[:requested_sleep_ms]).to eq(0)
      end

      it 'simulates for ">p50 to p75" band when p50=0 and p75=0' do
        controller = LatencyController.new
        stub_controller_rand(controller, 60)
        allow(LatencyController).to receive(:new).and_return(controller)
        get '/simulate_latency'
        json_response = response.parsed_body.deep_symbolize_keys
        expect(json_response[:conceptual_latency_range_ms]).to eq('0-0')
        expect(json_response[:requested_sleep_ms]).to eq(0)
      end
    end

    context 'when handling profile errors' do
      it 'returns an error when latency profile is empty' do
        stub_latency_profile({})
        get '/simulate_latency'
        expect(response).to have_http_status(:internal_server_error)
        json_response = response.parsed_body.deep_symbolize_keys
        expect(json_response[:error]).to include('Latency profile not loaded or is empty')
      end

      it 'returns an error when latency profile has missing keys' do
        stub_latency_profile(missing_keys_profile)
        get '/simulate_latency'
        expect(response).to have_http_status(:internal_server_error)
        json_response = response.parsed_body.deep_symbolize_keys
        expect(json_response[:error])
          .to include('Latency profile is missing, or has invalid (non-numeric) values for keys:')
        expect(json_response[:error]).to include('p95')
        expect(json_response[:error]).to include('p50')
      end

      it 'returns an error when latency profile has incorrectly ordered keys' do
        stub_latency_profile(invalid_order_profile)
        get '/simulate_latency'
        expect(response).to have_http_status(:internal_server_error)
        json_response = response.parsed_body.deep_symbolize_keys
        expect(json_response[:error])
          .to include('Latency profile values are not logically ordered')
        expect(json_response[:error])
          .to include("p90=#{invalid_order_profile[:p90]}")
        expect(json_response[:error])
          .to include("p95=#{invalid_order_profile[:p95]}")
      end
    end
  end
end
