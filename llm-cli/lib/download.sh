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
    done <<< "$(echo "$results" | grep -o '"id":"[^"]*"' | sed 's/"id":"//g' | sed 's/"//g')"

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

    # Count available GGUF files
    local gguf_count
    gguf_count=$(echo "$gguf_files" | wc -l | tr -d ' ')

    echo ""
    echo -e "${BOLD}Available GGUF files:${RESET}"
    echo ""

    local i=1
    declare -a GGUF_OPTIONS
    while IFS= read -r file; do
        [ -z "$file" ] && continue
        GGUF_OPTIONS[$i]="$file"
        echo -e "  ${CYAN}$i)${RESET} $file"
        ((i++))
    done <<< "$gguf_files"

    echo ""

    # Auto-select best quantization
    local selected_file
    selected_file=$(select_best_quantization "$gguf_files")

    if [ -n "$selected_file" ]; then
        local quant
        quant=$(echo "$selected_file" | grep -oE 'Q[0-9]+_K_[A-Z]+|Q[0-9]+_[0-9]+|IQ[0-9]+_[A-Z]+' || echo "default")
        log_info "Recommended: $selected_file ($quant)"
        echo ""

        if confirm "Download recommended file?" "y"; then
            download_file "$repo" "$selected_file"
            return
        fi
    fi

    # Manual selection
    read -rp "Select file to download (1-$((i-1))): " choice

    if ! [[ "$choice" =~ ^[0-9]+$ ]] || [ "$choice" -lt 1 ] || [ "$choice" -ge $i ]; then
        die "Invalid selection"
    fi

    selected_file="${GGUF_OPTIONS[$choice]}"
    download_file "$repo" "$selected_file"
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
