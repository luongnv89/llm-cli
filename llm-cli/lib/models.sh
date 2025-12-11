#!/bin/bash
# llm-cli: Model management functions
# Scan, list, info, delete, update cached models

# Global arrays for cached models
declare -a MODEL_NAMES
declare -a MODEL_PATHS
declare -a MODEL_REPOS
declare -a MODEL_DIRS
declare -a MODEL_FILES
declare -a MODEL_SIZES

# Scan HuggingFace cache for GGUF models
# Populates MODEL_* arrays
scan_cached_models() {
    MODEL_NAMES=()
    MODEL_PATHS=()
    MODEL_REPOS=()
    MODEL_DIRS=()
    MODEL_FILES=()
    MODEL_SIZES=()

    if [ ! -d "$HF_CACHE_DIR" ]; then
        return 1
    fi

    local idx=0

    for model_dir in "$HF_CACHE_DIR"/models--*; do
        [ -d "$model_dir" ] || continue

        # Extract repo name (models--user--repo -> user/repo)
        local dir_name
        dir_name=$(basename "$model_dir")
        local repo_name
        repo_name=$(echo "$dir_name" | sed 's/^models--//' | sed 's/--/\//g')

        local snapshot_dir="$model_dir/snapshots"
        [ -d "$snapshot_dir" ] || continue

        for snapshot in "$snapshot_dir"/*; do
            [ -d "$snapshot" ] || continue

            for gguf_file in "$snapshot"/*.gguf; do
                [ -e "$gguf_file" ] || continue

                local filename
                filename=$(basename "$gguf_file")

                # Resolve symlink to get actual file path
                local real_path
                real_path=$(readlink -f "$gguf_file" 2>/dev/null || echo "$gguf_file")

                # Get file size
                local size="N/A"
                if [ -f "$real_path" ]; then
                    size=$(du -h "$real_path" 2>/dev/null | cut -f1)
                fi

                MODEL_NAMES[$idx]="$repo_name ($filename)"
                MODEL_PATHS[$idx]="$real_path"
                MODEL_REPOS[$idx]="$repo_name"
                MODEL_DIRS[$idx]="$model_dir"
                MODEL_FILES[$idx]="$filename"
                MODEL_SIZES[$idx]="$size"

                ((idx++))
            done
        done
    done

    return 0
}

# Get model count
get_model_count() {
    echo "${#MODEL_NAMES[@]}"
}

# List cached models
cmd_models_list() {
    print_header "Cached GGUF Models"

    if ! scan_cached_models; then
        echo "No HuggingFace cache directory found."
        echo "Cache directory: $HF_CACHE_DIR"
        return 0
    fi

    local count=${#MODEL_NAMES[@]}

    if [ $count -eq 0 ]; then
        echo ""
        echo "No GGUF models found in cache."
        echo ""
        echo "Download a model with:"
        echo "  llm-cli search <query>"
        echo "  llm-cli download <repo>"
        return 0
    fi

    echo ""
    for i in "${!MODEL_NAMES[@]}"; do
        local num=$((i + 1))
        echo -e "  ${CYAN}$num)${RESET} ${MODEL_REPOS[$i]}"
        echo -e "     ${DIM}File:${RESET} ${MODEL_FILES[$i]} ${DIM}(${MODEL_SIZES[$i]})${RESET}"
        echo ""
    done

    echo -e "${BOLD}Total:${RESET} $count model(s)"
    echo ""
    echo "Commands:"
    echo "  llm-cli chat <N>          Start conversation"
    echo "  llm-cli models info <N>   View details"
    echo "  llm-cli bench <N>         Run benchmark"

    # Show GPU memory info on NVIDIA systems
    show_gpu_memory_info
}

# Show detailed model info
cmd_models_info() {
    local selection="$1"

    if ! scan_cached_models; then
        die "No cached models found"
    fi

    local count=${#MODEL_NAMES[@]}
    if [ $count -eq 0 ]; then
        die "No GGUF models found in cache"
    fi

    local idx
    if [ -z "$selection" ]; then
        # Interactive selection
        echo ""
        for i in "${!MODEL_NAMES[@]}"; do
            echo -e "  ${CYAN}$((i + 1)))${RESET} ${MODEL_NAMES[$i]} [${MODEL_SIZES[$i]}]"
        done
        echo ""
        read -rp "Select model (1-$count): " selection
    fi

    # Validate selection
    if ! [[ "$selection" =~ ^[0-9]+$ ]] || [ "$selection" -lt 1 ] || [ "$selection" -gt $count ]; then
        die "Invalid selection: $selection"
    fi

    idx=$((selection - 1))

    print_header "Model Information"
    echo ""
    echo -e "${BOLD}Repository:${RESET}  ${MODEL_REPOS[$idx]}"
    echo -e "${BOLD}File:${RESET}        ${MODEL_FILES[$idx]}"
    echo -e "${BOLD}Size:${RESET}        ${MODEL_SIZES[$idx]}"
    echo -e "${BOLD}Path:${RESET}        ${MODEL_PATHS[$idx]}"
    echo -e "${BOLD}Cache Dir:${RESET}   ${MODEL_DIRS[$idx]}"
    echo ""

    # Try to extract quantization info from filename
    local quant
    quant=$(echo "${MODEL_FILES[$idx]}" | grep -oE 'Q[0-9]+_K_[A-Z]+|Q[0-9]+_[0-9]+|IQ[0-9]+_[A-Z]+' || echo "Unknown")
    echo -e "${BOLD}Quantization:${RESET} $quant"

    # Show directory size (includes all files for this model)
    local dir_size
    dir_size=$(du -sh "${MODEL_DIRS[$idx]}" 2>/dev/null | cut -f1)
    echo -e "${BOLD}Total Cache:${RESET} $dir_size"
}

# Delete a cached model
cmd_models_delete() {
    local selection="$1"

    if ! scan_cached_models; then
        die "No cached models found"
    fi

    local count=${#MODEL_NAMES[@]}
    if [ $count -eq 0 ]; then
        die "No GGUF models found in cache"
    fi

    local idx
    if [ -z "$selection" ]; then
        # Interactive selection
        echo ""
        for i in "${!MODEL_NAMES[@]}"; do
            echo -e "  ${CYAN}$((i + 1)))${RESET} ${MODEL_NAMES[$i]} [${MODEL_SIZES[$i]}]"
        done
        echo ""
        read -rp "Select model to DELETE (1-$count) or 'q' to quit: " selection

        [ "$selection" = "q" ] || [ "$selection" = "Q" ] && exit 0
    fi

    # Validate selection
    if ! [[ "$selection" =~ ^[0-9]+$ ]] || [ "$selection" -lt 1 ] || [ "$selection" -gt $count ]; then
        die "Invalid selection: $selection"
    fi

    idx=$((selection - 1))

    local model_name="${MODEL_NAMES[$idx]}"
    local model_dir="${MODEL_DIRS[$idx]}"
    local dir_size
    dir_size=$(du -sh "$model_dir" 2>/dev/null | cut -f1)

    echo ""
    echo -e "${BOLD}Model:${RESET}     $model_name"
    echo -e "${BOLD}Directory:${RESET} $model_dir"
    echo -e "${BOLD}Size:${RESET}      $dir_size"
    echo ""

    if confirm "Delete this model?"; then
        log_info "Deleting..."
        if rm -rf "$model_dir"; then
            log_success "Model deleted. Freed $dir_size of disk space."
        else
            die "Failed to delete model"
        fi
    else
        echo "Deletion cancelled."
    fi
}

# Update a cached model
cmd_models_update() {
    local selection="$1"

    # Check for huggingface-cli
    if ! command -v huggingface-cli &>/dev/null; then
        die "huggingface-cli not found. Install with: pip install -U 'huggingface_hub[cli]'"
    fi

    if ! scan_cached_models; then
        die "No cached models found"
    fi

    local count=${#MODEL_NAMES[@]}
    if [ $count -eq 0 ]; then
        die "No GGUF models found in cache"
    fi

    local idx
    if [ -z "$selection" ]; then
        # Interactive selection
        echo ""
        for i in "${!MODEL_NAMES[@]}"; do
            echo -e "  ${CYAN}$((i + 1)))${RESET} ${MODEL_NAMES[$i]} [${MODEL_SIZES[$i]}]"
        done
        echo ""
        read -rp "Select model to UPDATE (1-$count) or 'q' to quit: " selection

        [ "$selection" = "q" ] || [ "$selection" = "Q" ] && exit 0
    fi

    # Validate selection
    if ! [[ "$selection" =~ ^[0-9]+$ ]] || [ "$selection" -lt 1 ] || [ "$selection" -gt $count ]; then
        die "Invalid selection: $selection"
    fi

    idx=$((selection - 1))

    local repo="${MODEL_REPOS[$idx]}"
    local filename="${MODEL_FILES[$idx]}"

    echo ""
    echo -e "${BOLD}Repository:${RESET} $repo"
    echo -e "${BOLD}File:${RESET}       $filename"
    echo ""
    log_info "Checking for updates..."

    if huggingface-cli download "$repo" "$filename" --force-download; then
        echo ""
        log_success "Model updated successfully!"
    else
        die "Failed to update model"
    fi
}

# Select model interactively (returns index 0-based)
# Usage: select_model "prompt"
# Returns: sets SELECTED_MODEL_IDX variable
select_model() {
    local prompt="${1:-Select a model}"

    if ! scan_cached_models; then
        die "No cached models found"
    fi

    local count=${#MODEL_NAMES[@]}
    if [ $count -eq 0 ]; then
        die "No GGUF models found. Download one first with: llm-cli search <query>"
    fi

    echo ""
    for i in "${!MODEL_NAMES[@]}"; do
        echo -e "  ${CYAN}$((i + 1)))${RESET} ${MODEL_NAMES[$i]} [${MODEL_SIZES[$i]}]"
    done
    echo ""

    local selection
    read -rp "$prompt (1-$count) or 'q' to quit: " selection

    [ "$selection" = "q" ] || [ "$selection" = "Q" ] && exit 0

    if ! [[ "$selection" =~ ^[0-9]+$ ]] || [ "$selection" -lt 1 ] || [ "$selection" -gt $count ]; then
        die "Invalid selection: $selection"
    fi

    SELECTED_MODEL_IDX=$((selection - 1))
}

# Get model path by index (1-based for user input, converts to 0-based)
get_model_path() {
    local num="$1"

    if ! scan_cached_models; then
        return 1
    fi

    local count=${#MODEL_NAMES[@]}
    if [ $count -eq 0 ]; then
        return 1
    fi

    if ! [[ "$num" =~ ^[0-9]+$ ]] || [ "$num" -lt 1 ] || [ "$num" -gt $count ]; then
        return 1
    fi

    local idx=$((num - 1))
    echo "${MODEL_PATHS[$idx]}"
}

# Get model name by index (1-based)
get_model_name() {
    local num="$1"

    if [ ${#MODEL_NAMES[@]} -eq 0 ]; then
        scan_cached_models
    fi

    local count=${#MODEL_NAMES[@]}
    if ! [[ "$num" =~ ^[0-9]+$ ]] || [ "$num" -lt 1 ] || [ "$num" -gt $count ]; then
        return 1
    fi

    local idx=$((num - 1))
    echo "${MODEL_NAMES[$idx]}"
}
