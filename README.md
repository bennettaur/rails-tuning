# README

This README would normally document whatever steps are necessary to get the
application up and running.

Things you may want to cover:

* Ruby version

* System dependencies

* Configuration

* Database creation

* Database initialization

* How to run the test suite

* Services (job queues, cache servers, search engines, etc.)

* Deployment instructions

* ...

## Latency Simulation Feature

This Rails application includes an API endpoint to simulate varying application response times based on a configurable latency profile. This is useful for load testing different Puma server configurations (workers/threads) against realistic application performance characteristics.

### Configuration

The latency profile is defined in `config/latency_profile.yml`. The file should contain the following keys, with values in milliseconds:

-   `max`: The absolute maximum latency a request might experience.
-   `p99`: The 99th percentile latency. 1% of requests will sleep for a duration between `p99` (exclusive, i.e., `p99 + 1`) and `max` (inclusive).
-   `p95`: The 95th percentile latency. 4% of requests will sleep between `p95 + 1` and `p99`.
-   `p90`: The 90th percentile latency. 5% of requests will sleep between `p90 + 1` and `p95`.
-   `p75`: The 75th percentile latency. 15% of requests will sleep between `p75 + 1` and `p90`.
-   `p50`: The 50th percentile latency. 25% of requests will sleep between `p50 + 1` and `p75`.
-   The remaining 50% of requests will sleep between `0` and `p50`.

**Important:** Percentile values must be logically ordered: `p50 <= p75 <= p90 <= p95 <= p99 <= max`. The application will return an error if this order is violated.

Example `config/latency_profile.yml`:

```yaml
max: 3000
p99: 200
p95: 100
p90: 75
p75: 50
p50: 25
```

The application loads this configuration at startup. If the file is missing or contains invalid/missing keys, the `/simulate_latency` endpoint will return an error.

### API Endpoint

-   **URL:** `/simulate_latency`
-   **Method:** `GET`
-   **Description:** When this endpoint receives a request, it determines a sleep duration based on the configured latency profile and the percentile distribution described above. After sleeping, it returns a JSON response.
-   **Success Response (200 OK):**
    ```json
    {
      "message": "Simulated latency based on profile.",
      "random_draw_percentile": 78, // The random number (1-100) drawn for this request
      "target_latency_band_label": ">p75 to p90", // Label for the selected percentile band
      "conceptual_latency_range_ms": "51-75", // The calculated min-max sleep range for this band (e.g., p75_value+1 to p90_value)
      "requested_sleep_ms": 65, // The actual duration (ms) the system was asked to sleep
      "actual_slept_ms": 65.12 // The measured duration (ms) of the sleep operation
    }
    ```
-   **Error Responses (500 Internal Server Error):**
    -   If `config/latency_profile.yml` is not loaded, empty, missing required keys, or has non-numeric values.
    -   If percentile values in the profile are not logically ordered.
    The JSON response body will contain an `error` field with details.

### How Sleep Durations Are Calculated

1.  A random number between 1 and 100 (inclusive) is chosen to determine the percentile category for the request.
2.  Based on the category, a latency range is determined:
    -   1-50th percentile: `[0, p50_val]`
    -   51st-75th percentile: `(p50_val, p75_val]` (i.e., `p50_val + 1` to `p75_val`)
    -   76th-90th percentile: `(p75_val, p90_val]`
    -   91st-95th percentile: `(p90_val, p95_val]`
    -   96th-99th percentile: `(p95_val, p99_val]`
    -   100th percentile: `(p99_val, max_latency]`
3.  A random duration within this specific range is chosen for the sleep.
4.  If percentile values are configured such that a lower bound for a range (e.g., `p50_val + 1`) would exceed its upper bound (e.g., `p75_val`, if `p50_val` is equal to or very close to `p75_val`), the sleep duration defaults to the upper bound of that percentile category (e.g., `p75_val`).

This mechanism allows for fine-grained control over the response time distribution for effective load testing.
