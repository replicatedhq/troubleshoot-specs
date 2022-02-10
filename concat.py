import yaml

# Open Collector yaml and convert it to dict
with open('./collectors.yaml') as collector:
    data_collector = yaml.safe_load(collector)

# Open Analyzer yaml and convert it to dict
with open('./analyzers.yaml') as analyzer:
    data_analyzer = yaml.safe_load(analyzer)

# Dict with the final spec
spec_final = {
  "apiVersion": "troubleshoot.sh/v1beta2",
  "kind": "SupportBundle",
  "metadata": {
    "name": "concat-spec",
  },
  "spec": {
    "collectors": {},
    "analyzers": {},
  },
}

# Concat the Collectors and Analyzers specs
spec_final["spec"]["collectors"]  = data_collector["spec"]["collectors"]
spec_final["spec"]["analyzers"]   = data_analyzer["spec"]["analyzers"]

# Write final spec file
with open(r'support-bundle.yaml', 'w') as support_bundle_file:
    spec_final_doc = yaml.dump(spec_final, support_bundle_file)
