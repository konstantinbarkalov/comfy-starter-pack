#!/bin/bash
# ==============================================================================
# SCRIPT LOGIC - Reads configuration and downloads single files with custom names.
# ==============================================================================

# --- Default Configuration Files ---
MODELS_FILE="models.json"
SECRETS_FILE="secrets.json"

# --- Script Counters ---
SUCCESS_COUNT=0
SKIP_COUNT=0
FAIL_COUNT=0

# --- Parse Command-Line Arguments ---
while [[ "$#" -gt 0 ]]; do
    case $1 in
        --models) MODELS_FILE="$2"; shift ;;
        --secrets) SECRETS_FILE="$2"; shift ;;
        *) echo "Unknown parameter passed: $1"; exit 1 ;;
    esac
    shift
done

# --- Color Definitions ---
C_RESET='\e[0m'
C_BOLD='\e[1m'
C_BLUE='\e[34m'
C_GREEN='\e[32m'
C_YELLOW='\e[33m'
C_RED='\e[31m'

# --- Helper for logging ---
log_msg() {
    local type=$1
    local color=$2
    shift 2
    echo -e "${color}${C_BOLD}[$type]${C_RESET}${color} $@${C_RESET}"
}

# --- Initial File and Dependency Checks ---
log_msg "INFO" "$C_BLUE" "Starting model downloader script..."

if ! command -v jq &> /dev/null; then
    log_msg "ERROR" "$C_RED" "'jq' is not installed. Please install it to proceed."
    exit 1
fi
if [ ! -f "$MODELS_FILE" ]; then
    log_msg "ERROR" "$C_RED" "Models file not found at '$MODELS_FILE'"
    exit 1
fi
if [ ! -f "$SECRETS_FILE" ]; then
    log_msg "ERROR" "$C_RED" "Secrets file not found at '$SECRETS_FILE'"
    log_msg "INFO" "$C_BLUE" "Please run the 'add_secrets.sh' script first to generate it."
    exit 1
fi

# --- Read Configuration from JSON files ---
CIVITAI_API_KEY=$(jq -r '.api_keys.civitai' "$SECRETS_FILE")
HUGGINGFACE_TOKEN=$(jq -r '.api_keys.huggingface' "$SECRETS_FILE")
BASE_DIR_RAW=$(jq -r '.directories.base' "$MODELS_FILE")
BASE_DIR=$(eval echo "$BASE_DIR_RAW")
CHECKPOINT_DIR="$BASE_DIR/$(jq -r '.directories.checkpoint' "$MODELS_FILE")" # CORRECTED
LORA_DIR="$BASE_DIR/$(jq -r '.directories.lora' "$MODELS_FILE")"             # CORRECTED
CONTROLNET_DIR="$BASE_DIR/$(jq -r '.directories.controlnet' "$MODELS_FILE")"
VAE_DIR="$BASE_DIR/$(jq -r '.directories.vae' "$MODELS_FILE")"
log_msg "INFO" "$C_BLUE" "Configuration loaded successfully."

# --- Directory Creation ---
mkdir -p "$CHECKPOINT_DIR" "$LORA_DIR" "$CONTROLNET_DIR" "$VAE_DIR"

# --- Download Functions ---

download_civitai() {
    local url=$1
    local dest_dir=$2
    local filename=$3
    local model_id=$(echo "$url" | grep -oP 'models/\K[0-9]+')
    
    local final_path="$dest_dir/$filename"
    if [ -f "$final_path" ]; then
        log_msg "SKIP" "$C_YELLOW" "File '$filename' already exists."
        return 2
    fi

    log_msg "INFO" "$C_BLUE" "Querying Civitai API for model ID: $model_id"
    local api_url="https://civitai.com/api/v1/models/$model_id"
    local json_response=$(curl -s -H "Authorization: Bearer $CIVITAI_API_KEY" "$api_url")
    local download_url=$(echo "$json_response" | jq -r '.modelVersions[0].files[0].downloadUrl')

    if [[ "$download_url" == "null" || -z "$download_url" ]]; then
        log_msg "ERROR" "$C_RED" "Failed to find a download URL in the API response for model ID $model_id."
        return 1
    fi

    log_msg "INFO" "$C_BLUE" "Starting download for '$filename'..."
    if ! wget -O "$final_path.tmp" "${download_url}?token=${CIVITAI_API_KEY}" --progress=bar:force; then
        log_msg "ERROR" "$C_RED" "Download failed for '$filename'. See wget output above."
        rm -f "$final_path.tmp"
        return 1
    fi

    mv "$final_path.tmp" "$final_path"
    log_msg "SUCCESS" "$C_GREEN" "Successfully downloaded '$filename'."
    return 0
}

download_huggingface() {
    local url=$1
    local dest_dir=$2
    local filename=$3
    
    local final_path="$dest_dir/$filename"
    if [ -f "$final_path" ]; then
        log_msg "SKIP" "$C_YELLOW" "File '$filename' already exists."
        return 2
    fi

    local download_url=${url/blob\//resolve/}
    
    local hf_header=""
    if [[ -n "$HUGGINGFACE_TOKEN" && "$HUGGINGFACE_TOKEN" != "YOUR_HUGGINGFACE_TOKEN_HERE" ]]; then
        hf_header="--header=\"Authorization: Bearer $HUGGINGFACE_TOKEN\""
    fi
    
    log_msg "INFO" "$C_BLUE" "Starting download for '$filename'..."
    if ! eval wget $hf_header -O "'$final_path.tmp'" "'$download_url'" --progress=bar:force; then
        log_msg "ERROR" "$C_RED" "Download failed for '$filename'. See wget output above."
        rm -f "$final_path.tmp"
        return 1
    fi

    mv "$final_path.tmp" "$final_path"
    log_msg "SUCCESS" "$C_GREEN" "Successfully downloaded '$filename'."
    return 0
}


# --- Main Processing Loop ---
total_models=$(jq '.models | length' "$MODELS_FILE")
current_model=0

log_msg "INFO" "$C_BLUE" "Found $total_models models to process."
echo -e "${C_BLUE}---------------------------------------------${C_RESET}"

while read -r model_json; do
    ((current_model++))
    url=$(echo "$model_json" | jq -r '.url')
    type=$(echo "$model_json" | jq -r '.type')
    filename=$(echo "$model_json" | jq -r '.filename')

    log_msg "INFO" "$C_BLUE" "Processing [${current_model}/${total_models}]: '$filename'"

    dest_dir=""
    case "$type" in
        "checkpoint") dest_dir="$CHECKPOINT_DIR" ;;
        "lora")       dest_dir="$LORA_DIR" ;;
        "controlnet") dest_dir="$CONTROLNET_DIR" ;;
        "vae")        dest_dir="$VAE_DIR" ;;
        *)
            log_msg "ERROR" "$C_RED" "Unknown model type '$type' for '$filename'. Skipping."
            ((FAIL_COUNT++)); continue ;;
    esac

    if [[ -z "$filename" || "$filename" == "null" ]]; then
        log_msg "ERROR" "$C_RED" "Missing 'filename' for URL '$url'. Skipping."
        ((FAIL_COUNT++)); continue
    fi

    result=0
    if [[ "$url" == *"civitai.com"* ]]; then
        download_civitai "$url" "$dest_dir" "$filename"
        result=$?
    elif [[ "$url" == *"huggingface.co"* ]]; then
        download_huggingface "$url" "$dest_dir" "$filename"
        result=$?
    else
        log_msg "ERROR" "$C_RED" "Unknown source for URL '$url'. Skipping."
        result=1
    fi

    case $result in
        0) ((SUCCESS_COUNT++)) ;;
        1) ((FAIL_COUNT++)) ;;
        2) ((SKIP_COUNT++)) ;;
    esac
    echo -e "${C_BLUE}---------------------------------------------${C_RESET}"
done < <(jq -c '.models[]' "$MODELS_FILE")

# --- Final Summary ---
log_msg "INFO" "$C_BLUE" "All tasks finished."
echo -e "${C_GREEN}Successful: $SUCCESS_COUNT${C_RESET}"
echo -e "${C_YELLOW}Skipped: $SKIP_COUNT${C_RESET}"
echo -e "${C_RED}Failed: $FAIL_COUNT${C_RESET}"

if [ "$FAIL_COUNT" -gt 0 ]; then exit 1; fi
exit 0
