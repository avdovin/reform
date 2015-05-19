require 'forwardable'
require 'uber/inheritable_attr'
require 'uber/delegates'
require 'ostruct'

module Reform
  # Gives you a DSL for defining the object structure and its validations.
  require "disposable/twin"
  require "disposable/twin/setup"
  class Contract < Disposable::Twin
    feature Setup

    twin_representer_class.instance_eval do
      def default_inline_class
        Contract
      end
    end
    # FIXME: THIS sucks because we're building two representers.
    representer_class.instance_eval do
      def default_inline_class
        Contract
      end
    end

    def self.property(name, options={}, &block)
      options.merge!(pass_options: true)

      if twin = options.delete(:form)
        options[:twin] = twin
      end

      super
    end

    # FIXME: make AM optional.
    require 'active_model'
    include ActiveModel::Validations

    require 'reform/contract/validate'
    include Reform::Contract::Validate

    def errors # FIXME: this is needed for Rails 3.0 compatibility.
      @errors ||= Errors.new(self)
    end

  private
    attr_writer :errors # only used in top form. (is that true?)

    # DISCUSS: can we achieve that somehow via features in build_inline?
    # TODO: check out if that is needed with Lotus::Validations and make it a AM feature.
    def self.process_inline!(mod, definition)
      _name = definition.name
      mod.instance_eval do
        @_name = _name
        def name # this adds Form::name for AM::Validations and I18N. i know it's retarded.
          @_name
        end
      end
    end
  end

  class Contract_ # DISCUSS: make class?
    extend Uber::InheritableAttr

    RESERVED_METHODS = [:model] # TODO: refactor that so we don't need that.


      def properties(*args)
        options = args.extract_options!
        args.each { |name| property(name, options.dup) }
      end

      def handle_reserved_names(name)
        raise "[Reform] the property name '#{name}' is reserved, please consider something else using :as." if RESERVED_METHODS.include?(name)
      end



    attr_accessor :model
    def self.deprecate_as!(options) # TODO: remove me in 2.0.
      return unless as = options.delete(:as)
      options[:from] = as
      warn "[Reform] The :as options got renamed to :from. See https://github.com/apotonick/reform/wiki/Migration-Guide and have a nice day."
    end



    # allows including representers from Representable, Roar or disposable.
    def self.inherit_module!(representer) # called from Representable::included.
      # representer_class.inherit_module!(representer)
      representer.representable_attrs.each do |dfn|
        next if dfn.name == "links" # wait a second # FIXME what is that?

        # TODO: remove manifesting and do that in representable, too!
        args = [dfn.name, dfn.instance_variable_get(:@options)] # TODO: dfn.to_args (inluding &block)

        property(*args) and next unless dfn.representer_module
        property(*args) { include dfn.representer_module } # nested.
      end
    end

    def self.clone
      Class.new(self)
    end

    require 'reform/schema'
    extend Schema
  end
end

require 'reform/contract/errors'
