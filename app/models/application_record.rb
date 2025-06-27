# frozen_string_literal: true

# ApplicationRecord is the base class for all models in the application.
# It inherits from ActiveRecord::Base and is abstract.
class ApplicationRecord < ActiveRecord::Base
  primary_abstract_class
end
