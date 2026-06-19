module EventEngine
  class SubjectRegistry
    class UnknownSubjectError < StandardError; end

    class Subject
      attr_reader :name, :metadata

      def initialize(name, **metadata)
        @name = name
        @metadata = metadata
      end
    end

    def self.define(&block)
      registry = new
      registry.instance_eval(&block) if block
      registry
    end

    def initialize
      @subjects = {}
    end

    def subject(name, **metadata)
      @subjects[name] = Subject.new(name, **metadata)
    end

    def [](name)
      @subjects[name]
    end

    def registered?(name)
      @subjects.key?(name)
    end

    def names
      @subjects.keys
    end
  end
end
