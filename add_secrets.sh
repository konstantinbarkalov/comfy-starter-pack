#!/bin/bash

# --- Default Values ---
SECRETS_FILE="secrets.json"
CIVITAI_KEY=""
HF_KEY=""

# --- Helper for showing usage ---
usage() {
    echo "Usage: $0 --civit <civitai_api_key> --hf <huggingface_token> [--secrets <filename>]"
    echo "  --civit    Required. Your Civitai API key."
    echo "  --hf       Required. Your Hugging Face token."
    echo "  --secrets  Optional. The output filename. Defaults to 'secrets.json'."
    exit 1
}

# --- Parse Command-Line Arguments ---
while [[ "$#" -gt 0 ]]; do
    case $1 in
        --civit) CIVITAI_KEY="$2"; shift ;;
        --hf) HF_KEY="$2"; shift ;;
        --secrets) SECRETS_FILE="$2"; shift ;;
        *) echo "Unknown parameter passed: $1"; usage ;;
    esac
    shift
done

# --- Validate Inputs ---
if [ -z "$CIVITAI_KEY" ] || [ -z "$HF_KEY" ]; then
    echo "Error: Both --civit and --hf arguments are required."
    usage
fi

# --- Create the JSON file ---
# Using printf to avoid dependency on jq for this simple script.
printf '{\n  "api_keys": {\n    "civitai": "%s",\n    "huggingface": "%s"\n  }\n}\n' \
"$CIVITAI_KEY" "$HF_KEY" > "$SECRETS_FILE"

echo "✅ Success! Secrets saved to '$SECRETS_FILE'."
echo "🔒 Remember to add this file to your .gitignore!"
