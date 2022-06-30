#!/bin/ruby

require 'yaml'

if ARGV[0].nil?
  puts "Usage: #{$0} parameters.yaml"
  exit 1
end

objects = YAML.load_stream(STDIN)
parameters = YAML.safe_load(File.open(ARGV[0]))

template = {
  'apiVersion' => 'v1',
  'kind' => 'Template',
  'metadata' => {
    'name' => 'floorist-operator'
  },
  'objects' => objects,
  'parameters' => parameters
}

YAML.dump(template, STDOUT)
