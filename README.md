# Overview

Troubleshoot specs for using when running with `support-bundle`.

## Folder Structure

`host`: Host Collectors and Analyzers to troubleshoot a kURL cluster. Useful when you need to gather information that isn't available with `in-cluster` collectors or if Kubernetes is offline. When run these will generate a support bundle with host level information about the host where the binary was executed.

`in-cluster`: Standard Collectors and Analyzers that can be used to retrieve information from a Kubernetes cluster
