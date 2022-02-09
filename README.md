# Overview

Troubleshoot specs for using when running with `support-bundle`.

# Folder Structure
`support-bundle.yaml`: This has the final yaml that gets run with the `support-bundle` command.

`analyzers`: Analyzers could be run on any support bundle as long as you have the bundle tarball.

`collectors`: Collectors depending on the level of access they need can be run either from CLI or need to be injected via a secret so they are parameterized and have proper access to run it.


