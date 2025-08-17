#!/bin/bash
# ==============================================================================
# SCRIPT LOGIC - Reads configuration from separate model and secret files.
# ==============================================================================
set -e

# --- Default Configuration Files ---
MODELS_FILE="models.json"
SECRETS_FILE="secrets.json"

# --- Parse Command-Line Arguments ---
while [[ "$#" -gt 0 ]]; do
    case $1 in
        --models) MODELS_FILE="$2"; shift ;;
        --secrets) SECRETS_FILE="$2"; shift ;;
        *) echo "Unknown parameter passed: $1"; exit 1 ;;
    esac
    shift
done

# --- File Existence Check ---
if [ ! -f "$MODELS_FILE" ]; then
    echo "❌ Error: Models file not found at '$MODELS_FILE'"
    exit 1
fi
if [ ! -f "$SECRETS_FILE" ]; then
    echo "❌ Error: Secrets file not found at '$SECRETS_FILE'"
    echo "💡 Please run the 'add_secrets.sh' script first to generate it."
    exit 1
fi

# --- Helper Functions ---
cecho() {
    local color_code=$1
    shift
    echo -e "\e[${color_code}m$@\e[0m"
}

# --- Dependency Check ---
for cmd in curl jq wget git; do
    if ! command -v $cmd &> /dev/null; then
        cecho "31" "❌ Error: Required command '$cmd' is not installed. Please install it."
        exit 1
    fi
done

# --- Read Configuration from JSON files using jq ---
cecho "36" "⚙️  Reading configuration..."
CIVITAI_API_KEY=$(jq -r '.api_keys.civitai' "$SECRETS_FILE")
HUGGINGFACE_TOKEN=$(jq -r '.api_keys.huggingface' "$SECRETS_FILE")

BASE_DIR_RAW=$(jq -r '.directories.base' "$MODELS_FILE")
BASE_DIR=$(eval echo "$BASE_DIR_RAW") # Safely expands variables like $HOME

CHECKPOINT_DIR="$BASE_DIR/$(jq -r '.directories.checkpoints' "$MODELS_FILE")"
LORA_DIR="$BASE_DIR/$(jq -r '.directories.loras' "$MODELS_FILE")"
CONTROLNET_DIR="$BASE_DIR/$(jq -r '.directories.controlnets' "$MODELS_FILE")"

# --- Directory Creation ---
echo "⚙️  Setting up download directories..."
mkdir -p "$CHECKPOINT_DIR" "$LORA_DIR" "$CONTROLNET_DIR"
echo "✅ Directories are ready."

# --- Download Functions (The Core Logic - Unchanged) ---

download_civitai() {
    local url=$1
    local dest_dir=$2
    local model_id=$(echo "$url" | grep -oP 'models/\K[0-9]+')
    
    cecho "36" "🔍 Querying Civitai API for: $(basename "$url")"
    local api_url="https://civitai.com/api/v1/models/$model_id"
    local json_response=$(curl -s -H "Authorization: Bearer $CIVITAI_API_KEY" "$api_url")
    local download_url=$(echo "$json_response" | jq -r '.modelVersions[0].files[0].downloadUrl')
    local filename=$(echo "$json_response" | jq -r '.modelVersions[0].files[0].name')

    if [[ "$download_url" == "null" || -z "$download_url" ]]; then
        cecho "31" "❌ Failed to get download URL for model ID $model_id."
        return
    fi

    local final_path="$dest_dir/$filename"
    if [ -f "$final_path" ]; then
        cecho "32" "👍 '$filename' already exists. Skipping."
    else
        echo "🔽 Downloading '$filename'..."
        wget -q --show-progress -O "$final_path" "${download_url}?token=${CIVITAI_API_KEY}"
        cecho "32" "✅ Download complete."
    fi
}

download_huggingface() {
    local url=$1
    local dest_dir=$2

    if [[ "$url" == *"/blob/"* || "$url" == *"/resolve/"* ]]; then
        local download_url=${url/blob\//resolve/}
        local filename=$(basename "$download_url")
        local final_path="$dest_dir/$filename"

        if [ -f "$final_path" ]; then
            cecho "32" "👍 '$filename' already exists. Skipping."
        else
            echo "🔽 Downloading single file '$filename'..."
            local wget_headers=""
            if [[ "$HUGGINGFACE_TOKEN" != "YOUR_HUGGINGFACE_TOKEN_HERE" && ! -z "$HUGGINGFACE_TOKEN" ]]; then
                wget_headers="--header=\"Authorization: Bearer $HUGGINGFACE_TOKEN\""
            fi
            eval wget -q --show-progress $wget_headers -O "$final_path" "$download_url"
            cecho "32" "✅ Download complete."
        fi
    else
        local repo_name=$(basename "$url")
        local final_path="$dest_dir/$repo_name"

        if [ -d "$final_path" ]; then
            cecho "32" "👍 Repository '$repo_name' already exists. Skipping."
        else
            echo "🔽 Cloning repository '$repo_name'..."
            local clone_url="https://huggingface.co/$(echo "$url" | awk -F'/' '{print $(NF-1)"/"$NF}')"
            if [[ "$HUGGINGFACE_TOKEN" != "YOUR_HUGGINGFACE_TOKEN_HERE" && ! -z "$HUGGINGFACE_TOKEN" ]]; then
                clone_url="https://user:$HUGGINGFACE_TOKEN@huggingface.co/$(echo "$url" | awk -F'/' '{print $(NF-1)"/"$NF}')"
            fi
            git clone "$clone_url" "$final_path"
            cecho "32" "✅ Clone complete."
        fi
    fi
}


# --- Main Processing Loop ---
cecho "34" "\n--- Starting Model Downloads ---"
jq -c '.models[]' "$MODELS_FILE" | while read -r model_json; do
    url=$(echo "$model_json" | jq -r '.url')
    type=$(echo "$model_json" | jq -r '.type')

    dest_dir=""
    case "$type" in
        "checkpoint") dest_dir="$CHECKPOINT_DIR" ;;
        "lora")       dest_dir="$LORA_DIR" ;;
        "controlnet") dest_dir="$CONTROLNET_DIR" ;;
        *)
            cecho "33" "⚠️  Warning: Unknown model type '$type' for URL '$url'. Skipping."
            continue
            ;;
    esac

    if [[ "$url" == *"civitai.com"* ]]; then
        download_civitai "$url" "$dest_dir"
    elif [[ "$url" == *"huggingface.co"* ]]; then
        download_huggingface "$url" "$dest_dir"
    else
        cecho "33" "⚠️  Warning: Unknown source for URL '$url'. Skipping."
    fi
done

cecho "32;1" "\n✨ All downloads finished! ✨\n"
