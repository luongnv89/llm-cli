#!/bin/bash
# llm-cli: Download and search functions
# Search HuggingFace, download models

# Search HuggingFace for GGUF models
# Returns JSON array of matching models
search_huggingface() {
    local query="$1"
    local limit="${2:-10}"

    # URL encode the query
    local encoded_query
    encoded_query=$(echo "$query" | sed 's/ /%20/g')

    # Search HuggingFace API for GGUF models
    local url="https://huggingface.co/api/models?search=${encoded_query}%20gguf&limit=${limit}&sort=downloads&direction=-1"

    curl -s "$url" 2>/dev/null
}

# Fetch list of files in a repository
fetch_repo_files() {
    local repo="$1"

    local url="https://huggingface.co/api/models/$repo"
    local response
    response=$(curl -s "$url" 2>/dev/null)

    # Check for error
    if echo "$response" | grep -q '"error"'; then
        return 1
    fi

    # Extract filenames
    echo "$response" | grep -o '"rfilename":"[^"]*"' | sed 's/"rfilename":"//g' | sed 's/"//g'
}

# Select best quantization from available files
# Prioritizes Q5_K_M > Q4_K_M > Q6_K > Q4_K_S > Q8_0 > any GGUF
select_best_quantization() {
    local files="$1"

    for quant in "${QUANT_PRIORITY[@]}"; do
        local match
        match=$(echo "$files" | grep -i "${quant}.gguf" | head -n 1)
        if [ -n "$match" ]; then
            echo "$match"
            return 0
        fi
    done

    # Fallback: any GGUF file
    echo "$files" | grep -i "\.gguf$" | head -n 1
}

# Search command
cmd_search() {
    local query="$1"

    if [ -z "$query" ]; then
        echo "Usage: llm-cli search <query>"
        echo ""
        echo "Examples:"
        echo "  llm-cli search llama-3.2"
        echo "  llm-cli search mistral"
        echo "  llm-cli search qwen2"
        exit 1
    fi

    # Check for huggingface-cli
    if ! command -v huggingface-cli &>/dev/null; then
        log_warn "huggingface-cli not found. Install for download capability:"
        log_warn "  pip install -U 'huggingface_hub[cli]'"
    fi

    log_info "Searching for '$query'..."

    local results
    results=$(search_huggingface "$query")

    if [ -z "$results" ] || [ "$results" = "[]" ]; then
        log_error "No models found matching '$query'"
        echo ""
        echo "Tips:"
        echo "  - Try a different search term"
        echo "  - Search for specific model families: llama, mistral, qwen, phi"
        exit 1
    fi

    print_header "Search Results: $query"
    echo ""

    # Parse JSON and display results
    local i=1
    declare -a RESULT_IDS

    while IFS= read -r repo_id; do
        [ -z "$repo_id" ] && continue

        RESULT_IDS[$i]="$repo_id"

        # Extract downloads count
        local downloads
        downloads=$(echo "$results" | grep -o "\"id\":\"$repo_id\"[^}]*\"downloads\":[0-9]*" | grep -o '"downloads":[0-9]*' | cut -d':' -f2)

        # Format downloads
        local downloads_fmt="$downloads"
        if [ -n "$downloads" ]; then
            if [ "$downloads" -ge 1000000 ]; then
                downloads_fmt="$(echo "scale=1; $downloads / 1000000" | bc)M"
            elif [ "$downloads" -ge 1000 ]; then
                downloads_fmt="$(echo "scale=1; $downloads / 1000" | bc)K"
            fi
        fi

        echo -e "  ${CYAN}$i)${RESET} $repo_id"
        [ -n "$downloads" ] && echo -e "     ${DIM}Downloads: $downloads_fmt${RESET}"
        echo ""

        ((i++))
    done <<<"$(echo "$results" | grep -o '"id":"[^"]*"' | sed 's/"id":"//g' | sed 's/"//g')"

    local count=$((i - 1))

    if [ $count -eq 0 ]; then
        log_error "No valid repositories found"
        exit 1
    fi

    echo ""
    read -rp "Select model to download (1-$count) or 'q' to quit: " choice

    [ "$choice" = "q" ] || [ "$choice" = "Q" ] && exit 0

    if ! [[ "$choice" =~ ^[0-9]+$ ]] || [ "$choice" -lt 1 ] || [ "$choice" -gt $count ]; then
        die "Invalid selection: $choice"
    fi

    local selected_repo="${RESULT_IDS[$choice]}"
    echo ""
    log_info "Selected: $selected_repo"

    # Download the selected model
    do_download "$selected_repo"
}

# Download command
cmd_download() {
    local repo="$1"

    if [ -z "$repo" ]; then
        echo "Usage: llm-cli download <repository>"
        echo ""
        echo "Examples:"
        echo "  llm-cli download bartowski/Llama-3.2-3B-Instruct-GGUF"
        echo "  llm-cli download hugging-quants/Llama-3.2-1B-Instruct-Q8_0-GGUF"
        echo ""
        echo "Find models with: llm-cli search <query>"
        exit 1
    fi

    do_download "$repo"
}

# Group GGUF files by quantization type
# For split models like Q5_K_M-00001-of-00002.gguf, groups all parts together
# Bash 3.2 compatible (no associative arrays)
group_gguf_files() {
    local files="$1"

    while IFS= read -r file; do
        [ -z "$file" ] && continue

        # Extract quantization type (handle split files and directory prefixes)
        local base_name
        base_name=$(basename "$file")

        # Remove split suffixes like -00001-of-00002
        local group_key
        group_key=$(echo "$base_name" | sed -E 's/-[0-9]+-of-[0-9]+\.gguf$/.gguf/')

        # Also handle directory prefixes like Q5_K_M/filename.gguf
        local dir_prefix=""
        if echo "$file" | grep -q '/'; then
            dir_prefix=$(dirname "$file")/
        fi

        echo "${dir_prefix}${group_key}"
    done <<<"$files" | sort -u
}

# Get all files for a quantization group (handles split models)
get_group_files() {
    local all_files="$1"
    local group="$2"

    # Remove .gguf extension to create pattern
    local pattern
    pattern=$(echo "$group" | sed 's/\.gguf$//')

    # Match exact file or split parts
    echo "$all_files" | grep -E "^${pattern}(-[0-9]+-of-[0-9]+)?\.gguf$" | sort
}

# Internal download function
do_download() {
    local repo="$1"

    # Check for huggingface-cli
    if ! command -v huggingface-cli &>/dev/null; then
        die "huggingface-cli not found. Install with: pip install -U 'huggingface_hub[cli]'"
    fi

    log_info "Fetching file list from $repo..."

    local files
    files=$(fetch_repo_files "$repo")

    if [ -z "$files" ]; then
        die "Could not fetch files from repository: $repo"
    fi

    # Check for GGUF files
    local gguf_files
    gguf_files=$(echo "$files" | grep -i "\.gguf$" || true)

    if [ -z "$gguf_files" ]; then
        log_error "No GGUF files found in $repo"
        echo ""
        echo "This repository may not contain quantized models."
        echo "Try searching for a GGUF version:"
        echo "  llm-cli search $(echo "$repo" | sed 's|.*/||')"
        exit 1
    fi

    # Check if this is a split model (has -00001-of- pattern)
    local has_splits=false
    if echo "$gguf_files" | grep -qE '\-[0-9]+-of-[0-9]+\.gguf'; then
        has_splits=true
    fi

    echo ""
    echo -e "${BOLD}Available quantizations:${RESET}"
    echo ""

    # Group files by quantization
    local i=1
    declare -a QUANT_OPTIONS
    declare -a QUANT_FILES

    if [ "$has_splits" = true ]; then
        # For split models, show grouped quantizations
        local groups
        groups=$(group_gguf_files "$gguf_files")

        while IFS= read -r group; do
            [ -z "$group" ] && continue

            # Get all files in this group
            local group_files
            group_files=$(get_group_files "$gguf_files" "$group")
            local file_count
            file_count=$(echo "$group_files" | wc -l | tr -d ' ')

            # Extract quant type for display
            local quant_type
            quant_type=$(echo "$group" | grep -oE 'Q[0-9]+_K_[A-Z]+|Q[0-9]+_[0-9]+|Q[0-9]+_K|IQ[0-9]+_[A-Z]+|UD-Q[0-9]+_K_[A-Z]+|F16' | head -1 || echo "unknown")

            QUANT_OPTIONS[$i]="$group"
            QUANT_FILES[$i]="$group_files"

            if [ "$file_count" -gt 1 ]; then
                echo -e "  ${CYAN}$i)${RESET} $quant_type ${DIM}($file_count parts)${RESET}"
            else
                echo -e "  ${CYAN}$i)${RESET} $group"
            fi
            ((i++))
        done <<<"$groups"
    else
        # Single files, show directly
        while IFS= read -r file; do
            [ -z "$file" ] && continue
            QUANT_OPTIONS[$i]="$file"
            QUANT_FILES[$i]="$file"
            echo -e "  ${CYAN}$i)${RESET} $file"
            ((i++))
        done <<<"$gguf_files"
    fi

    echo ""

    # Auto-select best quantization
    local recommended_idx=""
    for idx in "${!QUANT_OPTIONS[@]}"; do
        local opt="${QUANT_OPTIONS[$idx]}"
        for quant in "${QUANT_PRIORITY[@]}"; do
            if echo "$opt" | grep -qi "$quant"; then
                recommended_idx=$idx
                break 2
            fi
        done
    done

    if [ -n "$recommended_idx" ]; then
        local rec_opt="${QUANT_OPTIONS[$recommended_idx]}"
        local quant_type
        quant_type=$(echo "$rec_opt" | grep -oE 'Q[0-9]+_K_[A-Z]+|Q[0-9]+_[0-9]+|Q[0-9]+_K' | head -1 || echo "recommended")
        log_info "Recommended: $quant_type"
        echo ""

        if confirm "Download recommended ($quant_type)?" "y"; then
            download_files "$repo" "${QUANT_FILES[$recommended_idx]}"
            return
        fi
    fi

    # Manual selection
    read -rp "Select quantization to download (1-$((i - 1))): " choice

    if ! [[ "$choice" =~ ^[0-9]+$ ]] || [ "$choice" -lt 1 ] || [ "$choice" -ge $i ]; then
        die "Invalid selection"
    fi

    download_files "$repo" "${QUANT_FILES[$choice]}"
}

# Download a specific file
download_file() {
    local repo="$1"
    local filename="$2"

    echo ""
    log_info "Downloading $filename..."
    echo ""

    if huggingface-cli download "$repo" "$filename"; then
        echo ""
        log_success "Download complete!"
        echo ""
        echo "Run with:"
        echo "  llm-cli chat"
        echo ""
        echo "Or benchmark:"
        echo "  llm-cli bench"
    else
        die "Download failed"
    fi
}

# Download multiple files (for split models)
download_files() {
    local repo="$1"
    local files="$2"

    # Count files
    local file_count
    file_count=$(echo "$files" | grep -c '.' || echo 0)

    echo ""
    if [ "$file_count" -gt 1 ]; then
        log_info "Downloading $file_count files..."
    else
        log_info "Downloading..."
    fi
    echo ""

    local success=true
    local downloaded=0

    while IFS= read -r file; do
        [ -z "$file" ] && continue

        if [ "$file_count" -gt 1 ]; then
            ((downloaded++))
            echo -e "${DIM}[$downloaded/$file_count]${RESET} $file"
        fi

        if ! huggingface-cli download "$repo" "$file"; then
            log_error "Failed to download: $file"
            success=false
            break
        fi
    done <<<"$files"

    if [ "$success" = true ]; then
        echo ""
        log_success "Download complete!"
        echo ""
        echo "Run with:"
        echo "  llm-cli chat"
        echo ""
        echo "Or benchmark:"
        echo "  llm-cli bench"
    else
        die "Download failed"
    fi
}
