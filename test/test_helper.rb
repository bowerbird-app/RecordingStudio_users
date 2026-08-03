# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)

require_relative "simplecov_helper"
require "minitest/autorun"
require "rails"
require "recording_studio_users"

unless Object.new.respond_to?(:stub)
	class Object
		def stub(name, value = nil)
			new_name = "__minitest_stub__#{name}"
			metaclass = class << self; self; end

			if metaclass.method_defined?(name) || metaclass.private_method_defined?(name)
				metaclass.alias_method(new_name, name)
			end

			metaclass.define_method(name) do |*args, **kwargs, &block|
				if value.respond_to?(:call)
					value.call(*args, **kwargs, &block)
				else
					value
				end
			end

			yield self
		ensure
			metaclass.undef_method(name)
			if metaclass.method_defined?(new_name) || metaclass.private_method_defined?(new_name)
				metaclass.alias_method(name, new_name)
				metaclass.undef_method(new_name)
			end
		end
	end
end
