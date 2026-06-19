module EventEngine
  # Registry of subjects: the capabilities or features a group of related events
  # describes. Declared once by the host app and used to validate that event
  # definitions reference a known subject.
  #
  # @example Declare subjects
  #   EventEngine::SubjectRegistry.define do
  #     subject :export_csv
  #     subject :feeding
  #   end
  class SubjectRegistry
    # A single registered subject.
    class Subject
      # @return [Symbol] the subject name
      attr_reader :name

      # @return [Hash] arbitrary declared attributes (e.g. area, owner)
      attr_reader :metadata

      # @param name [Symbol]
      # @param metadata [Hash]
      def initialize(name, **metadata)
        @name = name
        @metadata = metadata
      end
    end

    # Builds a registry from a block of +subject+ declarations.
    #
    # @yield evaluated in the registry instance
    # @return [SubjectRegistry]
    def self.define(&block)
      registry = new
      registry.instance_eval(&block) if block
      registry
    end

    def initialize
      @subjects = {}
    end

    # Declares a subject.
    #
    # @param name [Symbol]
    # @param metadata [Hash] arbitrary attributes (e.g. area, owner)
    # @return [Subject]
    def subject(name, **metadata)
      @subjects[name] = Subject.new(name, **metadata)
    end

    # Looks up a subject by name.
    #
    # @param name [Symbol]
    # @return [Subject, nil]
    def [](name)
      @subjects[name]
    end

    # Whether a subject with the given name has been declared.
    #
    # @param name [Symbol]
    # @return [Boolean]
    def registered?(name)
      @subjects.key?(name)
    end

    # All declared subject names, in declaration order.
    #
    # @return [Array<Symbol>]
    def names
      @subjects.keys
    end
  end
end
