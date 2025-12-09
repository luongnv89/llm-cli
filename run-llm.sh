#!/bin/bash

# Configuration for M1 Max
# M1 Max has 10 CPU cores (8 Performance + 2 Efficiency).
# Using ONLY Performance cores prevents stuttering from efficiency core handoffs.
THREADS=8
GPU_LAYERS=99  # Offload everything to the GPU (Metal)
CONTEXT_SIZE=4096 # Adjustable based on your RAM (32GB/64GB can handle much more)
HF_CACHE_DIR="${HF_HOME:-$HOME/.cache/huggingface}/hub"

# Check dependencies
check_dependencies() {
    if ! command -v llama-cli &> /dev/null; then
        echo "Error: llama-cli not found. Make sure you installed it (brew install llama.cpp)"
        exit 1
    fi
}

# Function to list all cached/downloaded GGUF models
list_cached_models() {
    echo "Cached GGUF Models (offline available):"
    echo "========================================"

    if [ ! -d "$HF_CACHE_DIR" ]; then
        echo "No cached models found."
        echo "Cache directory: $HF_CACHE_DIR"
        exit 0
    fi

    local i=1
    declare -a CACHED_MODELS
    declare -a CACHED_PATHS

    # Find all model directories
    for model_dir in "$HF_CACHE_DIR"/models--*; do
        if [ -d "$model_dir" ]; then
            # Extract repo name from directory name (models--user--repo -> user/repo)
            local dir_name=$(basename "$model_dir")
            local repo_name=$(echo "$dir_name" | sed 's/^models--//' | sed 's/--/\//g')

            # Find GGUF files in snapshots
            local snapshot_dir="$model_dir/snapshots"
            if [ -d "$snapshot_dir" ]; then
                for snapshot in "$snapshot_dir"/*; do
                    if [ -d "$snapshot" ]; then
                        # Find all .gguf files (they are symlinks to blobs)
                        for gguf_file in "$snapshot"/*.gguf; do
                            if [ -e "$gguf_file" ]; then
                                local filename=$(basename "$gguf_file")
                                local real_path=$(readlink -f "$gguf_file" 2>/dev/null || echo "$gguf_file")
                                local size=""
                                if [ -f "$real_path" ]; then
                                    size=$(du -h "$real_path" 2>/dev/null | cut -f1)
                                fi

                                CACHED_MODELS[$i]="$repo_name|$filename"
                                CACHED_PATHS[$i]="$gguf_file"

                                if [ -n "$size" ]; then
                                    echo "  $i) $repo_name"
                                    echo "     File: $filename ($size)"
                                else
                                    echo "  $i) $repo_name"
                                    echo "     File: $filename"
                                fi
                                echo ""
                                ((i++))
                            fi
                        done
                    fi
                done
            fi
        fi
    done

    if [ ${#CACHED_MODELS[@]} -eq 0 ]; then
        echo "No GGUF models found in cache."
        echo "Download a model first: ./run-llm.sh <model_name>"
        exit 0
    fi

    echo "Total: $((i-1)) model(s) available offline"
    echo ""
    echo "To run a model offline:"
    echo "  ./run-llm.sh --offline <number>"
    echo "  ./run-llm.sh --offline    (interactive selection)"

    # Export for use in offline mode
    export CACHED_MODELS_LIST="${CACHED_MODELS[*]}"
    export CACHED_PATHS_LIST="${CACHED_PATHS[*]}"
}

# Helper function to get cached models info
# Sets global arrays: CACHED_MODELS, CACHED_PATHS, CACHED_REPOS, CACHED_DIRS
get_cached_models() {
    local show_list="$1"  # "show" to print list, empty to just populate arrays

    CACHED_MODELS=()
    CACHED_PATHS=()
    CACHED_REPOS=()
    CACHED_DIRS=()

    if [ ! -d "$HF_CACHE_DIR" ]; then
        return 1
    fi

    local i=1

    for model_dir in "$HF_CACHE_DIR"/models--*; do
        if [ -d "$model_dir" ]; then
            local dir_name=$(basename "$model_dir")
            local repo_name=$(echo "$dir_name" | sed 's/^models--//' | sed 's/--/\//g')

            local snapshot_dir="$model_dir/snapshots"
            if [ -d "$snapshot_dir" ]; then
                for snapshot in "$snapshot_dir"/*; do
                    if [ -d "$snapshot" ]; then
                        for gguf_file in "$snapshot"/*.gguf; do
                            if [ -e "$gguf_file" ]; then
                                local filename=$(basename "$gguf_file")
                                local real_path=$(readlink -f "$gguf_file" 2>/dev/null || echo "$gguf_file")
                                local size=""
                                if [ -f "$real_path" ]; then
                                    size=$(du -h "$real_path" 2>/dev/null | cut -f1)
                                fi

                                CACHED_MODELS[$i]="$repo_name ($filename)"
                                CACHED_PATHS[$i]="$real_path"
                                CACHED_REPOS[$i]="$repo_name"
                                CACHED_DIRS[$i]="$model_dir"

                                if [ "$show_list" = "show" ]; then
                                    if [ -n "$size" ]; then
                                        echo "  $i) $repo_name ($filename) [$size]"
                                    else
                                        echo "  $i) $repo_name ($filename)"
                                    fi
                                fi
                                ((i++))
                            fi
                        done
                    fi
                done
            fi
        fi
    done

    return 0
}

# Function to run a model offline (from cache)
run_offline() {
    local selection="$1"

    check_dependencies

    echo "Scanning cached models..."
    echo ""

    if ! get_cached_models ""; then
        echo "No cached models found."
        exit 1
    fi

    if [ ${#CACHED_MODELS[@]} -eq 0 ]; then
        echo "No GGUF models found in cache."
        echo "Download a model first: ./run-llm.sh <model_name>"
        exit 1
    fi

    local choice="$selection"

    # If no selection provided, show list and prompt user
    if [ -z "$choice" ]; then
        get_cached_models "show"
        echo ""
        read -p "Select a model (1-${#CACHED_MODELS[@]}) or 'q' to quit: " choice
    fi

    if [ "$choice" = "q" ] || [ "$choice" = "Q" ]; then
        echo "Exiting."
        exit 0
    fi

    if ! [[ "$choice" =~ ^[0-9]+$ ]] || [ "$choice" -lt 1 ] || [ "$choice" -gt ${#CACHED_MODELS[@]} ]; then
        echo "Invalid selection: $choice"
        exit 1
    fi

    local MODEL_PATH="${CACHED_PATHS[$choice]}"
    local MODEL_NAME="${CACHED_MODELS[$choice]}"

    echo ""
    echo "Selected: $MODEL_NAME"
    echo "Path: $MODEL_PATH"
    echo ""
    echo "Starting Inference on M1 Max (Metal Enabled) [OFFLINE MODE]..."
    echo "---------------------------------------------------------------"

    llama-cli \
      -m "$MODEL_PATH" \
      -p "You are a helpful AI assistant. Answer safely and concisely." \
      -n 512 \
      -c $CONTEXT_SIZE \
      -t $THREADS \
      -ngl $GPU_LAYERS \
      --color \
      -cnv

    exit 0
}

# Function to delete a cached model
delete_model() {
    local selection="$1"

    echo "Scanning cached models..."
    echo ""

    if ! get_cached_models ""; then
        echo "No cached models found."
        exit 1
    fi

    if [ ${#CACHED_MODELS[@]} -eq 0 ]; then
        echo "No GGUF models found in cache."
        exit 0
    fi

    local choice="$selection"

    # If no selection provided, show list and prompt user
    if [ -z "$choice" ]; then
        get_cached_models "show"
        echo ""
        read -p "Select model to DELETE (1-${#CACHED_MODELS[@]}) or 'q' to quit: " choice
    fi

    if [ "$choice" = "q" ] || [ "$choice" = "Q" ]; then
        echo "Exiting."
        exit 0
    fi

    if ! [[ "$choice" =~ ^[0-9]+$ ]] || [ "$choice" -lt 1 ] || [ "$choice" -gt ${#CACHED_MODELS[@]} ]; then
        echo "Invalid selection: $choice"
        exit 1
    fi

    local MODEL_NAME="${CACHED_MODELS[$choice]}"
    local MODEL_DIR="${CACHED_DIRS[$choice]}"
    local MODEL_PATH="${CACHED_PATHS[$choice]}"

    # Get size before deletion
    local size=$(du -sh "$MODEL_DIR" 2>/dev/null | cut -f1)

    echo ""
    echo "Model to delete: $MODEL_NAME"
    echo "Directory: $MODEL_DIR"
    echo "Size: $size"
    echo ""
    read -p "Are you sure you want to delete this model? (y/N): " confirm

    if [ "$confirm" = "y" ] || [ "$confirm" = "Y" ]; then
        echo "Deleting..."
        rm -rf "$MODEL_DIR"
        if [ $? -eq 0 ]; then
            echo "Model deleted successfully. Freed $size of disk space."
        else
            echo "Error: Failed to delete model."
            exit 1
        fi
    else
        echo "Deletion cancelled."
    fi

    exit 0
}

# Function to update a cached model (re-download latest version)
update_model() {
    local selection="$1"

    if ! command -v huggingface-cli &> /dev/null; then
        echo "Error: huggingface-cli is not installed. Run: pip install -U \"huggingface_hub[cli]\""
        exit 1
    fi

    echo "Scanning cached models..."
    echo ""

    if ! get_cached_models ""; then
        echo "No cached models found."
        exit 1
    fi

    if [ ${#CACHED_MODELS[@]} -eq 0 ]; then
        echo "No GGUF models found in cache."
        exit 0
    fi

    local choice="$selection"

    # If no selection provided, show list and prompt user
    if [ -z "$choice" ]; then
        get_cached_models "show"
        echo ""
        read -p "Select model to UPDATE (1-${#CACHED_MODELS[@]}) or 'q' to quit: " choice
    fi

    if [ "$choice" = "q" ] || [ "$choice" = "Q" ]; then
        echo "Exiting."
        exit 0
    fi

    if ! [[ "$choice" =~ ^[0-9]+$ ]] || [ "$choice" -lt 1 ] || [ "$choice" -gt ${#CACHED_MODELS[@]} ]; then
        echo "Invalid selection: $choice"
        exit 1
    fi

    local MODEL_NAME="${CACHED_MODELS[$choice]}"
    local MODEL_REPO="${CACHED_REPOS[$choice]}"
    local MODEL_PATH="${CACHED_PATHS[$choice]}"
    local FILENAME=$(basename "$MODEL_PATH")

    # Handle symlinked paths - get the actual filename from snapshot
    if [ -L "${CACHED_PATHS[$choice]}" ]; then
        # Find the original symlink to get actual filename
        local snapshot_dir="${CACHED_DIRS[$choice]}/snapshots"
        for snapshot in "$snapshot_dir"/*; do
            for gguf in "$snapshot"/*.gguf; do
                if [ "$(readlink -f "$gguf")" = "$MODEL_PATH" ]; then
                    FILENAME=$(basename "$gguf")
                    break 2
                fi
            done
        done
    fi

    echo ""
    echo "Updating: $MODEL_NAME"
    echo "Repository: $MODEL_REPO"
    echo "File: $FILENAME"
    echo ""
    echo "Checking for updates..."

    # Force re-download by using --force-download
    huggingface-cli download "$MODEL_REPO" "$FILENAME" --force-download

    if [ $? -eq 0 ]; then
        echo ""
        echo "Model updated successfully!"
    else
        echo ""
        echo "Error: Failed to update model."
        exit 1
    fi

    exit 0
}

# Function to benchmark a model
benchmark_model() {
    local selection="$1"

    check_dependencies

    # Check if llama-bench exists
    if ! command -v llama-bench &> /dev/null; then
        echo "Error: llama-bench not found. Make sure you installed llama.cpp (brew install llama.cpp)"
        exit 1
    fi

    echo "Scanning cached models..."
    echo ""

    if ! get_cached_models ""; then
        echo "No cached models found."
        exit 1
    fi

    if [ ${#CACHED_MODELS[@]} -eq 0 ]; then
        echo "No GGUF models found in cache."
        echo "Download a model first: ./run-llm.sh <model_name>"
        exit 1
    fi

    local choice="$selection"

    # If no selection provided, show list and prompt user
    if [ -z "$choice" ]; then
        get_cached_models "show"
        echo ""
        read -p "Select model to BENCHMARK (1-${#CACHED_MODELS[@]}) or 'q' to quit: " choice
    fi

    if [ "$choice" = "q" ] || [ "$choice" = "Q" ]; then
        echo "Exiting."
        exit 0
    fi

    if ! [[ "$choice" =~ ^[0-9]+$ ]] || [ "$choice" -lt 1 ] || [ "$choice" -gt ${#CACHED_MODELS[@]} ]; then
        echo "Invalid selection: $choice"
        exit 1
    fi

    local MODEL_PATH="${CACHED_PATHS[$choice]}"
    local MODEL_NAME="${CACHED_MODELS[$choice]}"

    echo ""
    echo "Benchmarking: $MODEL_NAME"
    echo "Path: $MODEL_PATH"
    echo ""
    echo "Configuration:"
    echo "  - Threads: $THREADS"
    echo "  - GPU Layers: $GPU_LAYERS"
    echo "  - Prompt tokens: 512"
    echo "  - Generated tokens: 128"
    echo "  - Repetitions: 3"
    echo ""
    echo "Running benchmark (this may take a minute)..."
    echo "=============================================="
    echo ""

    llama-bench \
        -m "$MODEL_PATH" \
        -t $THREADS \
        -ngl $GPU_LAYERS \
        -p 512 \
        -n 128 \
        -r 3 \
        --progress

    echo ""
    echo "Benchmark complete!"
    echo ""
    echo "Legend:"
    echo "  pp = Prompt Processing (tokens/sec) - How fast it processes input"
    echo "  tg = Text Generation (tokens/sec) - How fast it generates output"

    exit 0
}

# Function to benchmark all cached models
benchmark_all() {
    check_dependencies

    if ! command -v llama-bench &> /dev/null; then
        echo "Error: llama-bench not found. Make sure you installed llama.cpp (brew install llama.cpp)"
        exit 1
    fi

    echo "Scanning cached models..."
    echo ""

    if ! get_cached_models ""; then
        echo "No cached models found."
        exit 1
    fi

    if [ ${#CACHED_MODELS[@]} -eq 0 ]; then
        echo "No GGUF models found in cache."
        exit 1
    fi

    echo "Found ${#CACHED_MODELS[@]} model(s) to benchmark"
    echo ""
    echo "Configuration:"
    echo "  - Threads: $THREADS"
    echo "  - GPU Layers: $GPU_LAYERS"
    echo "  - Prompt tokens: 512"
    echo "  - Generated tokens: 128"
    echo "  - Repetitions: 2"
    echo ""

    read -p "Benchmark all models? This may take several minutes. (y/N): " confirm
    if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
        echo "Cancelled."
        exit 0
    fi

    echo ""
    echo "=============================================="
    echo "BENCHMARK RESULTS"
    echo "=============================================="
    echo ""

    for i in "${!CACHED_MODELS[@]}"; do
        echo "[$i/${#CACHED_MODELS[@]}] ${CACHED_MODELS[$i]}"
        echo "----------------------------------------------"

        llama-bench \
            -m "${CACHED_PATHS[$i]}" \
            -t $THREADS \
            -ngl $GPU_LAYERS \
            -p 512 \
            -n 128 \
            -r 2

        echo ""
    done

    echo "=============================================="
    echo "All benchmarks complete!"
    echo ""
    echo "Legend:"
    echo "  pp = Prompt Processing (tokens/sec)"
    echo "  tg = Text Generation (tokens/sec)"

    exit 0
}

# Show usage
show_usage() {
    echo "Usage: ./run-llm.sh [OPTIONS] [model_name_or_repo]"
    echo ""
    echo "Options:"
    echo "  --list, -l              List all cached/downloaded models"
    echo "  --offline, -o [N]       Run a cached model offline"
    echo "  --delete, -d [N]        Delete a cached model"
    echo "  --update, -u [N]        Update/re-download a cached model"
    echo "  --benchmark, -b [N]     Benchmark a cached model (tokens/sec)"
    echo "  --benchmark-all         Benchmark all cached models"
    echo "  --help, -h              Show this help message"
    echo ""
    echo "Online Mode (download & run):"
    echo "  ./run-llm.sh llama-3.2                    Search and download a model"
    echo "  ./run-llm.sh bartowski/Llama-3.2-GGUF     Download from specific repo"
    echo ""
    echo "Offline Mode (manage cached models):"
    echo "  ./run-llm.sh --list                       List all cached models"
    echo "  ./run-llm.sh --offline                    Run cached model (interactive)"
    echo "  ./run-llm.sh --offline 1                  Run first cached model"
    echo "  ./run-llm.sh --delete                     Delete a cached model"
    echo "  ./run-llm.sh --delete 2                   Delete second cached model"
    echo "  ./run-llm.sh --update 1                   Update first cached model"
    echo "  ./run-llm.sh --benchmark                  Benchmark a model"
    echo "  ./run-llm.sh --benchmark 1                Benchmark first cached model"
    echo "  ./run-llm.sh --benchmark-all              Benchmark all cached models"
    exit 0
}

# Parse command line arguments
case "$1" in
    --list|-l)
        list_cached_models
        exit 0
        ;;
    --offline|-o)
        run_offline "$2"
        exit 0
        ;;
    --delete|-d)
        delete_model "$2"
        exit 0
        ;;
    --update|-u)
        update_model "$2"
        exit 0
        ;;
    --benchmark|-b)
        benchmark_model "$2"
        exit 0
        ;;
    --benchmark-all)
        benchmark_all
        exit 0
        ;;
    --help|-h)
        show_usage
        ;;
    "")
        show_usage
        ;;
esac

# Online mode - check for huggingface-cli
if ! command -v huggingface-cli &> /dev/null; then
    echo "Error: huggingface-cli is not installed. Run: pip install -U \"huggingface_hub[cli]\""
    exit 1
fi

check_dependencies

MODEL_REPO=$1

# Function to search for available models based on a name using Hugging Face API
search_models() {
    local search_term="$1"
    # URL encode the search term
    local encoded_term=$(echo "$search_term" | sed 's/ /%20/g')
    # Search for GGUF models on Hugging Face using the API
    local results=$(curl -s "https://huggingface.co/api/models?search=${encoded_term}%20gguf&limit=10&sort=downloads&direction=-1" 2>/dev/null)
    echo "$results"
}

# Function to try fetching files from a repo using Hugging Face API
try_fetch_repo() {
    local repo="$1"
    # Use the API to get file list
    local api_response=$(curl -s "https://huggingface.co/api/models/$repo" 2>/dev/null)
    if echo "$api_response" | grep -q '"error"'; then
        echo ""
        return 1
    fi
    # Extract filenames from siblings array
    echo "$api_response" | grep -o '"rfilename":"[^"]*"' | sed 's/"rfilename":"//g' | sed 's/"//g'
}

echo "Scanning $MODEL_REPO for GGUF files..."

# 1. Fetch the file list and find the best quantization
# Priority: Q5_K_M (Best balance for M1 Max) -> Q4_K_M (Faster/Smaller) -> Any GGUF
ALL_FILES=$(try_fetch_repo "$MODEL_REPO")

# If fetching fails, search for available models
if [ -z "$ALL_FILES" ] || echo "$ALL_FILES" | grep -qi "error\|not found\|404"; then
    echo "Could not find repository: $MODEL_REPO"
    echo ""
    echo "Searching for available models..."

    # Extract search term from the input (could be repo name or just model name)
    SEARCH_TERM=$(echo "$MODEL_REPO" | sed 's|.*/||' | sed 's/-GGUF$//' | sed 's/_GGUF$//')

    SEARCH_RESULTS=$(search_models "$SEARCH_TERM")

    if [ -z "$SEARCH_RESULTS" ] || [ "$SEARCH_RESULTS" = "[]" ]; then
        echo "No models found matching '$SEARCH_TERM'"
        echo "Try a different search term or provide a full repository path."
        exit 1
    fi

    echo ""
    echo "Available models matching '$SEARCH_TERM':"
    echo "----------------------------------------"

    # Parse JSON results and display (requires no external JSON parser)
    # Extract modelId fields from JSON array
    i=1
    declare -a MODEL_OPTIONS

    # Use grep and sed to extract model IDs from JSON
    while IFS= read -r repo_id; do
        if [ -n "$repo_id" ]; then
            MODEL_OPTIONS[$i]="$repo_id"
            # Try to extract downloads count for display
            downloads=$(echo "$SEARCH_RESULTS" | grep -o "\"id\":\"$repo_id\"[^}]*\"downloads\":[0-9]*" | grep -o '"downloads":[0-9]*' | cut -d':' -f2)
            if [ -n "$downloads" ]; then
                echo "  $i) $repo_id (${downloads} downloads)"
            else
                echo "  $i) $repo_id"
            fi
            ((i++))
        fi
    done <<< "$(echo "$SEARCH_RESULTS" | grep -o '"id":"[^"]*"' | sed 's/"id":"//g' | sed 's/"//g')"

    if [ ${#MODEL_OPTIONS[@]} -eq 0 ]; then
        echo "No valid GGUF repositories found."
        echo "Try searching with a different term or provide a full repository path."
        exit 1
    fi

    echo ""
    read -p "Select a model (1-$((i-1))) or 'q' to quit: " choice

    if [ "$choice" = "q" ] || [ "$choice" = "Q" ]; then
        echo "Exiting."
        exit 0
    fi

    if ! [[ "$choice" =~ ^[0-9]+$ ]] || [ "$choice" -lt 1 ] || [ "$choice" -ge "$i" ]; then
        echo "Invalid selection."
        exit 1
    fi

    MODEL_REPO="${MODEL_OPTIONS[$choice]}"
    echo ""
    echo "Selected: $MODEL_REPO"
    echo "Scanning $MODEL_REPO for GGUF files..."
    ALL_FILES=$(try_fetch_repo "$MODEL_REPO")

    if [ -z "$ALL_FILES" ]; then
        echo "Failed to fetch files from $MODEL_REPO"
        exit 1
    fi
fi

if echo "$ALL_FILES" | grep -q "Q5_K_M.gguf"; then
    FILENAME=$(echo "$ALL_FILES" | grep "Q5_K_M.gguf" | head -n 1)
    echo "Found High-Quality Quantization: $FILENAME"
elif echo "$ALL_FILES" | grep -q "Q4_K_M.gguf"; then
    FILENAME=$(echo "$ALL_FILES" | grep "Q4_K_M.gguf" | head -n 1)
    echo "Found Standard Quantization: $FILENAME"
else
    # Fallback: Just grab the first GGUF found
    FILENAME=$(echo "$ALL_FILES" | grep ".gguf" | head -n 1)
    if [ -z "$FILENAME" ]; then
        echo "No GGUF files found in this repo!"
        echo "Tip: Standard repos (like meta-llama/Llama-3) don't work directly."
        echo "Try searching for a GGUF version (e.g., 'bartowski/Llama-3...GGUF')"
        exit 1
    fi
    echo "Specific optimizations not found. Defaulting to: $FILENAME"
fi

# 2. Download ONLY that specific file (uses HF cache system)
echo "⬇️  Downloading/Verifying model..."
MODEL_PATH=$(huggingface-cli download "$MODEL_REPO" "$FILENAME")

# 3. Run Inference with M1 Max Flags
echo "🚀 Starting Inference on M1 Max (Metal Enabled)..."
echo "---------------------------------------------------"

llama-cli \
  -m "$MODEL_PATH" \
  -p "You are a helpful AI assistant. Answer safely and concisely." \
  -n 512 \
  -c $CONTEXT_SIZE \
  -t $THREADS \
  -ngl $GPU_LAYERS \
  --color \
  -cnv  # Conversation mode (chat-like interaction)
