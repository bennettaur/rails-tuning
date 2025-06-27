# frozen_string_literal: true

# app/controllers/latency_controller.rb
class LatencyController < ApplicationController
  def simulate
    simulator = LatencySimulator.new(LATENCY_PROFILE)
    result = simulator.simulate
    if result[:error]
      render json: { error: result[:error] }, status: :internal_server_error
    else
      render json: result, status: :ok
    end
  end
end
