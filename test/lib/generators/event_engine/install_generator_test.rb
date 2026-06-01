require "test_helper"
require "generators/event_engine/install_generator"

module EventEngine
  module Generators
    class InstallGeneratorTest < ActiveSupport::TestCase
      test "has a generate_subagents method" do
        assert_includes InstallGenerator.instance_methods, :generate_subagents
      end
    end
  end
end
