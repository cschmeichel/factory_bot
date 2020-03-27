module FactoryBot
  # @api private
  class Definition
    attr_reader :defined_traits, :declarations, :name, :registered_enums

    def initialize(name, base_traits = [])
      @name              = name
      @declarations      = DeclarationList.new(name)
      @callbacks         = []
      @defined_traits    = Set.new
      @registered_enums  = []
      @to_create         = nil
      @base_traits       = base_traits
      @additional_traits = []
      @constructor       = nil
      @attributes        = nil
      @compiled          = false
    end

    delegate :declare_attribute, to: :declarations

    def attributes
      @attributes ||= AttributeList.new.tap do |attribute_list|
        attribute_lists = aggregate_from_traits_and_self(:attributes) { declarations.attributes }
        attribute_lists.each do |attributes|
          attribute_list.apply_attributes attributes
        end
      end
    end

    def to_create(&block)
      if block_given?
        @to_create = block
      else
        aggregate_from_traits_and_self(:to_create) { @to_create }.last
      end
    end

    def constructor
      aggregate_from_traits_and_self(:constructor) { @constructor }.last
    end

    def callbacks
      aggregate_from_traits_and_self(:callbacks) { @callbacks }
    end

    def compile
      unless @compiled
        declarations.attributes

        defined_traits.each do |defined_trait|
          base_traits.each       { |bt| bt.define_trait defined_trait }
          additional_traits.each { |bt| bt.define_trait defined_trait }
        end

        @compiled = true
      end
    end

    def automatically_register_defined_enums(klass)
      return unless klass.respond_to?(:defined_enums)
      klass.defined_enums.each_key do |name|
        register_enum(Enum.new(name))
      end
    end

    def expand_enum_traits(klass)
      registered_enums.each do |enum|
        traits = enum.build_traits(klass)
        traits.each { |trait| define_trait(trait) }
      end
    end

    def overridable
      declarations.overridable
      self
    end

    def inherit_traits(new_traits)
      @base_traits += new_traits
    end

    def append_traits(new_traits)
      @additional_traits += new_traits
    end

    def add_callback(callback)
      @callbacks << callback
    end

    def skip_create
      @to_create = ->(instance) {}
    end

    def define_trait(trait)
      @defined_traits.add(trait)
    end

    def register_enum(enum)
      @registered_enums << enum
    end

    def define_constructor(&block)
      @constructor = block
    end

    def before(*names, &block)
      callback(*names.map { |name| "before_#{name}" }, &block)
    end

    def after(*names, &block)
      callback(*names.map { |name| "after_#{name}" }, &block)
    end

    def callback(*names, &block)
      names.each do |name|
        FactoryBot.register_callback(name)
        add_callback(Callback.new(name, block))
      end
    end

    private

    def base_traits
      @base_traits.map { |name| trait_by_name(name) }
    end

    def additional_traits
      @additional_traits.map { |name| trait_by_name(name) }
    end

    def trait_by_name(name)
      trait_for(name) || FactoryBot.trait_by_name(name)
    end

    def trait_for(name)
      defined_traits.detect { |trait| trait.name == name }
    end

    def initialize_copy(source)
      super
      @attributes = nil
      @compiled   = false
    end

    def aggregate_from_traits_and_self(method_name, &block)
      compile

      [
        base_traits.map(&method_name),
        instance_exec(&block),
        additional_traits.map(&method_name),
      ].flatten.compact
    end
  end
end
