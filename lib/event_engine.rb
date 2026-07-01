require_relative "event_engine/version"

require "event_engine/engine"
require "event_engine/configuration"
require "event_engine/process_type"
require "event_engine/event_definition"
require "event_engine/lifecycle_definition"
require "event_engine/event_builder"
require "event_engine/handler_registry"
require "event_engine/event_schema"
require "event_engine/schema_registry"
require "event_engine/subject_registry"
require "event_engine/event"
require "event_engine/dsl_compiler"
require "event_engine/event_schema_loader"
require "event_engine/event_schema_writer"
require "event_engine/event_schema_merger"
require "event_engine/event_schema_dumper"
require "event_engine/schema_drift_guard"
require "event_engine/schema_compatibility"
require "event_engine/schema_catalog"
require "event_engine/railtie"
require "event_engine/definition_loader"
require "event_engine/the_local"

# EventEngine is the schema-first core of the event pipeline.
#
# Events are defined via a Ruby DSL and compiled into a canonical schema file.
# At boot, a helper method is installed on this module for each registered event
# (e.g. +EventEngine.cow_fed(cow: cow)+); the helper validates inputs, builds an
# +Event+, and dispatches it to registered handlers by level. Companion gems
# (e.g. event_engine-delivery) register handlers to process the events.
#
# @example Define, build, and dispatch an event
#   EventEngine.register_handler(MyHandler, levels: :all)
#   EventEngine.cow_fed(cow: cow, occurred_at: Time.current)
module EventEngine
  mattr_accessor :_installed_event_helpers, default: Set.new
  mattr_accessor :active_registry
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
    #     config.logger = Rails.logger
    #   end
    def configure
      yield(configuration)
    end

    def handler_registry
      @handler_registry ||= HandlerRegistry.new
    end

    def subject_registry
      @subject_registry ||= SubjectRegistry.new
    end

    def define_subjects(&block)
      subject_registry.instance_eval(&block)
    end

    def reset_subjects!
      @subject_registry = nil
    end

    def enriched_metadata(call_site_metadata)
      defaults = evaluated_metadata_defaults
      return call_site_metadata if defaults.nil?

      defaults.merge(call_site_metadata || {})
    end

    def evaluated_metadata_defaults
      callable = configuration.metadata_defaults
      return nil unless callable

      callable.call
    rescue => error
      configuration.logger&.error("EventEngine metadata_defaults raised: #{error.message}")
      nil
    end

    def register_handler(handler, levels:)
      handler_registry.register(handler, levels: levels)
    end

    def dispatch(event)
      handler_registry.dispatch(event)
    end

    def emit(event_name, inputs:, event_version: nil, occurred_at: nil, metadata: nil,
             idempotency_key: nil, aggregate_type: nil, aggregate_id: nil, aggregate_version: nil)
      schema = active_registry.schema(event_name, version: event_version)
      attrs = EventBuilder.build(schema: schema, data: inputs)
      attrs[:occurred_at] = occurred_at || Time.current
      attrs[:metadata] = enriched_metadata(metadata)
      attrs[:idempotency_key] = idempotency_key || SecureRandom.uuid
      attrs[:aggregate_type] = aggregate_type
      attrs[:aggregate_id] = aggregate_id
      attrs[:aggregate_version] = aggregate_version
      attrs[:process_type] = schema.process_type
      attrs[:subject] = schema.subject
      attrs[:domain] = schema.domain
      dispatch(Event.new(**attrs))
    end

    def reset_handlers!
      handler_registry.clear!
    end

    # Loads a schema file, populates the registry, and installs helper methods.
    # Called automatically by the engine at Rails boot.
    #
    # @param schema_path [String, Pathname] path to the compiled schema file
    # @param registry [SchemaRegistry] the registry to populate
    # @return [EventSchema] the loaded schema
    def boot_from_schema!(schema_path:, registry:)
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

          schema = registry.schema(event_name, version: event_version)
          attrs = EventBuilder.build(schema: schema, data: inputs)
          attrs[:occurred_at] = occurred_at || Time.current
          attrs[:metadata] = EventEngine.enriched_metadata(metadata)
          attrs[:idempotency_key] = idempotency_key || SecureRandom.uuid
          attrs[:aggregate_type] = aggregate_type
          attrs[:aggregate_id] = aggregate_id
          attrs[:aggregate_version] = aggregate_version
          attrs[:process_type] = schema.process_type
          attrs[:subject] = schema.subject
          attrs[:domain] = schema.domain

          EventEngine.dispatch(Event.new(**attrs))
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
