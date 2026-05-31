require_relative "event_engine/version"

require "event_engine/engine"
require "event_engine/locking_strategy"
require "event_engine/outbox_publisher"
require "event_engine/transports/in_memory_transport"
require "event_engine/transports/kafka"
require "event_engine/transports/null_transport"
require "event_engine/kafka_producer"
require "event_engine/configuration"
require "event_engine/event_definition"
require "event_engine/event_emitter"
require "event_engine/event_builder"
require "event_engine/outbox_writer"
require "event_engine/event_schema"
require "event_engine/schema_registry"
require "event_engine/subscriber_registry"
require "event_engine/dsl_compiler"
require "event_engine/event_schema_loader"
require "event_engine/event_schema_writer"
require "event_engine/event_schema_merger"
require "event_engine/event_schema_dumper"
require "event_engine/delivery"
require "event_engine/schema_drift_guard"
require "event_engine/railtie"
require "event_engine/definition_loader"
require "event_engine/cloud/serializer"
require "event_engine/cloud/batch"
require "event_engine/cloud/api_client"
require "event_engine/cloud/subscribers"
require "event_engine/cloud/reporter"

# EventEngine is a Rails engine providing a schema-first event pipeline.
#
# Events are defined via a Ruby DSL, compiled into a canonical schema file,
# persisted to an outbox table, and delivered through pluggable transports.
#
# At boot, helper methods are installed on this module for each registered
# event (e.g. +EventEngine.cow_fed(cow: cow)+).
#
# @example Configure and emit an event
#   EventEngine.configure do |config|
#     config.transport = EventEngine::Transports::InMemoryTransport.new
#   end
#
#   EventEngine.cow_fed(cow: cow, occurred_at: Time.current)
#
# @example Enable Cloud Reporter
#   EventEngine.configure do |config|
#     config.cloud_api_key = ENV["EVENT_ENGINE_CLOUD_KEY"]
#   end
module EventEngine
  mattr_accessor :_installed_event_helpers, default: Set.new
  class << self
    # Returns the current configuration instance.
    #
    # @return [Configuration]
    def configuration
      @configuration ||= Configuration.new
    end

    # Yields the configuration for modification.
    #
    # @yieldparam config [Configuration] the configuration instance
    # @example
    #   EventEngine.configure do |config|
    #     config.delivery_adapter = :active_job
    #     config.transport = MyTransport.new
    #   end
    def configure
      yield(configuration)
    end

    # Loads a schema file, populates the registry, and installs helper methods.
    # Called automatically by the engine at Rails boot.
    #
    # @param schema_path [String, Pathname] path to the compiled schema file
    # @param registry [SchemaRegistry] the registry to populate
    # @return [EventSchema] the loaded schema
    # @raise [Configuration::InvalidConfigurationError] if configuration is invalid
    def boot_from_schema!(schema_path:, registry:)
      configuration.validate!
      event_schema = EventSchemaLoader.load(schema_path)

      registry.reset!
      registry.load_from_schema!(event_schema)

      install_helpers(registry: registry)

      event_schema
    end

    # Installs singleton helper methods on the EventEngine module for each
    # event in the registry. Previous helpers are removed first.
    #
    # @param registry [SchemaRegistry] the loaded registry
    def install_helpers(registry:)
      _installed_event_helpers.each do |method_name|
        singleton_class.remove_method(method_name) if singleton_class.method_defined?(method_name)
      end
      _installed_event_helpers.clear

      registry.events.each do |event_name|
        schema = registry.schema(event_name)

        required = schema.required_inputs
        optional = schema.optional_inputs

        define_singleton_method(event_name) do |**args|
          event_version = args.delete(:event_version)
          occurred_at = args.delete(:occurred_at)
          metadata = args.delete(:metadata)
          idempotency_key = args.delete(:idempotency_key)
          aggregate_type = args.delete(:aggregate_type)
          aggregate_id = args.delete(:aggregate_id)
          aggregate_version = args.delete(:aggregate_version)

          input_keys = required + optional
          inputs = args.slice(*input_keys)

          missing = required - inputs.keys
          raise ArgumentError, "Missing required inputs: #{missing.join(', ')}" if missing.any?

          unknown = args.keys - input_keys
          raise ArgumentError, "Unknown inputs: #{unknown.join(', ')}" if unknown.any?

          EventEmitter.emit(
            event_name: event_name,
            data: inputs,
            registry: registry,
            version: event_version,
            occurred_at: occurred_at,
            metadata: metadata,
            idempotency_key: idempotency_key,
            aggregate_type: aggregate_type,
            aggregate_id: aggregate_id,
            aggregate_version: aggregate_version
          )
        end

        _installed_event_helpers << event_name
      end
    end

    # Compiles event definitions from source into a registry.
    # Used by rake tasks for schema drift detection.
    #
    # @return [SchemaRegistry]
    def compiled_schema_registry
      DefinitionLoader.ensure_loaded!
      definitions = EventDefinition.descendants
      compiled = DslCompiler.compile(definitions)
      registry = SchemaRegistry.new
      registry.load_from_schema!(compiled)
      registry
    end

    # Loads the committed schema file into a registry.
    # Used by rake tasks for schema drift detection.
    #
    # @return [SchemaRegistry]
    def file_schema_registry
      loaded = EventSchemaLoader.load(Rails.root.join("db/event_schema.rb"))
      registry = SchemaRegistry.new
      registry.load_from_schema!(loaded)
      registry
    end
  end
end
