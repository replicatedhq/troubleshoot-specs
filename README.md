# Overview

Troubleshoot specs for using when running with `support-bundle`.

# Folder Structure
`analyzers.yaml`: Analyzers could be run on any support bundle as long as you have the bundle tarball.

`collectors.yaml`: Collectors depending on the level of access they need can be run either from CLI or need to be injected via a secret so they are parameterized and have proper access to run it.

# GitHub Action

The action runs a workflow that concats the various analyzer and collector yaml files into a single troubleshoot spec `support-bundle.yaml` using `concat.py`.
