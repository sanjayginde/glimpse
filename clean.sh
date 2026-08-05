#!/bin/bash
echo "🧹 Cleaning build artifacts..."
rm -rf .build/
rm -rf "Glimps.app"/
swift package clean
echo "✅ Build artifacts removed!"
