#!/bin/sh

echo "// swift-tools-version: 5.7" > Package.swift
echo "// This file is auto-generated. Do not edit this file directly. Instead, make changes in \`Package/\` directory and then run \`package.sh\` to generate a new \`Package.swift\` file." >> Package.swift
cat Package/Support/*.swift >> Package.swift
cat Package/Sources/**/*.swift >> Package.swift
cat Package/Sources/*.swift >> Package.swift
