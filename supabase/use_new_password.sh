#!/bin/bash

# Script to use new password with supabase db push
# Usage: ./use_new_password.sh YOUR_PASSWORD

if [ -z "$1" ]; then
    echo "Usage: $0 YOUR_PASSWORD"
    echo "Or run interactively:"
    echo "cd /Users/russellmiller/Projects/POCUS_APP/POCUS_Mentor"
    echo "supabase db push --yes -p 'YOUR_PASSWORD'"
    exit 1
fi

PASSWORD="$1"
cd /Users/russellmiller/Projects/POCUS_APP/POCUS_Mentor

echo "Pushing migrations with new password..."
supabase db push --yes -p "$PASSWORD"

