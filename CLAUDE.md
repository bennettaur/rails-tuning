# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Common Commands

### Setup
```bash
# Install dependencies 
cd rails-tuning
bundle install
```

### Database Operations
```bash
# Create and migrate the database
cd rails-tuning
rails db:create
rails db:migrate

# Run database seeds
rails db:seed
```

### Development
```bash
# Start the Rails server
cd rails-tuning
rails server

# Start the Rails console
cd rails-tuning
rails console
```

### Testing
```bash
# Run all tests
cd rails-tuning
rails test

# Run specific test file
cd rails-tuning
rails test test/path/to/file_test.rb

# Run specific test
cd rails-tuning
rails test test/path/to/file_test.rb:line_number
```

### Linting and Security Analysis
```bash
# Run RuboCop for style checking
cd rails-tuning
bin/rubocop

# Run Brakeman for security analysis
cd rails-tuning
bin/brakeman
```

### Docker
```bash
# Build the Docker image
cd rails-tuning
docker build -t rails-tuning .

# Run the application in Docker
cd rails-tuning
docker run -p 3000:3000 rails-tuning
```

## Code Architecture

The Rails-Tuning project is designed to be a Ruby on Rails application for experimenting with performance tuning of Rails applications with different profiles.

### Project Structure

- **Root directory**: Contains basic setup for the Rails tuning project
- **rails-tuning/**: The main Rails application
  - API-only Rails application (ActionController::API)
  - Uses SQLite3 as the database
  - Uses Puma as the web server

### Key Components

1. **Rails 7.2**: The project uses Rails 7.2, which is the latest version
2. **API-only**: The application is configured as API-only (no views)
3. **Development Tools**:
   - Brakeman for security scanning
   - RuboCop Rails Omakase for Ruby style enforcement
   - Debug gem for debugging

### Configuration Notes

- The application uses SQLite3 for the database in all environments
- The Docker configuration is set up for production deployment with jemalloc for memory optimization
- The application uses the default Rails configurations with minimal customizations