module EventEngine
  class SchemaDiff
    def initialize(expected:, actual:)
      @expected = expected
      @actual = actual
    end

    def changed?
      false
    end
  end
end
