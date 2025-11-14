#!/bin/bash
# Quick script to increment build number for TestFlight

cd "$(dirname "$0")"

echo "Current build number:"
agvtool what-version 2>/dev/null || echo "Unable to read version"

echo ""
echo "Incrementing build number..."
agvtool next-version -all

echo ""
echo "New build number:"
agvtool what-version

echo ""
echo "✅ Build number incremented! Ready for archive."



