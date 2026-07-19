#!/bin/bash
if command -v mise >/dev/null 2>&1; then
  mise settings add idiomatic_version_file_enable_tools node
  mise settings add idiomatic_version_file_enable_tools java
  mise settings add idiomatic_version_file_enable_tools maven
fi

