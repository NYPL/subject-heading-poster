class SHEP
  class SubfieldDataManager
    attr_reader :value, :tag

    def initialize(value, tag)
      @value = value
      @tag = tag
    end

    def value_tag
      "#{value} {#{tag}}"
    end
  end
end
