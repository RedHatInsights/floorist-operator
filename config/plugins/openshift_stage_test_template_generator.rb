#!/bin/ruby

require 'yaml'

objects = YAML.load_stream(STDIN)

# Replacing namespace 'default' with 'floorist-operator-system' due to the difference in namespaces
# between the local (minikube) and staging environments
stage_namespace = 'floorist-operator-system'

objects.each do |object|
  # Replacing 'name' key with 'generateName' key ensuring Job name uniqueness in the staging environment
  if object['kind'] == 'Job'
    object['metadata']['name'] += '-'
    object['metadata']['generateName'] = object['metadata'].delete('name')
  end

  object['subjects'][0]['namespace'] = stage_namespace if object['kind'] == 'RoleBinding'

  object['metadata']['namespace'] = stage_namespace
end

template = {
  'apiVersion' => 'v1',
  'kind' => 'Template',
  'metadata' => {
    'name' => 'floorist-operator-stage-test'
  },
  'objects' => objects
}

YAML.dump(template, STDOUT)
