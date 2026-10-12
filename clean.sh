#!/bin/bash
echo "🧹 Cleaning build artifacts..."
rm -rf .build/
rm -rf "Glimpse.app"/
swift package clean
echo "✅ Build artifacts removed!"
