#!/bin/bash
# llm-cli: Download and search functions
# Search HuggingFace, download models

# Detect available download methods and their status
# Returns: method_name available_flag reason
get_download_method_status() {
    local method="$1"

    case "$method" in
        hf-cli)
            # Check for 'hf' command (new HuggingFace CLI)
            if command -v hf &>/dev/null; then
                echo "hf-cli true Available"
            else
                echo "hf-cli false Not installed"
            fi
            ;;
        huggingface-cli)
            # Check for 'huggingface-cli' command (old HuggingFace CLI)
            if command -v huggingface-cli &>/dev/null; then
                echo "huggingface-cli true Available"
            else
                echo "huggingface-cli false Not installed"
            fi
            ;;
        curl)
            # curl is almost always available
            if command -v curl &>/dev/null; then
                echo "curl true Available (native)"
            else
                echo "curl false Not installed"
            fi
            ;;
    esac
}

# Show download method selection and reasoning
show_download_method_info() {
    echo ""
    echo -e "${BOLD}📥 Download Method:${RESET}"
    echo ""

    # Check available methods in priority order
    local selected_method=""
    local methods=("hf-cli" "huggingface-cli" "curl")

    # Show status of all methods
    echo -e "${DIM}Available methods (in priority order):${RESET}"
    for method in "${methods[@]}"; do
        local status
        status=$(get_download_method_status "$method")
        local method_name available reason
        read -r method_name available reason <<<"$status"

        if [ "$available" = "true" ]; then
            if [ -z "$selected_method" ]; then
                selected_method="$method_name"
                echo -e "  ✅ ${GREEN}${method_name}${RESET} - $reason (${GREEN}SELECTED${RESET})"
            else
                echo -e "  ⊘ ${DIM}${method_name}${RESET} - $reason (skipped, using $selected_method)"
            fi
        else
            echo -e "  ✗ ${DIM}${method_name}${RESET} - $reason"
        fi
    done

    echo ""
    echo -e "${DIM}Using: ${BOLD}${selected_method}${RESET}"

    # Show method explanation
    case "$selected_method" in
        hf-cli)
            echo -e "${DIM}HuggingFace CLI tool (hf) - Modern, efficient, recommended${RESET}"
            echo -e "${DIM}Handles authentication, resumable downloads, and caching${RESET}"
            ;;
        huggingface-cli)
            echo -e "${DIM}HuggingFace CLI tool (huggingface-cli) - Legacy tool${RESET}"
            echo -e "${DIM}Handles authentication, resumable downloads, and caching${RESET}"
            ;;
        curl)
            echo -e "${DIM}curl - Universal fallback method${RESET}"
            echo -e "${DIM}Direct HTTPS download, works everywhere, no dependencies${RESET}"
            ;;
    esac
    echo ""
}

# Show platform-specific quantization recommendations
show_quant_recommendations() {
    case "$PLATFORM" in
        linux-nvidia)
            echo ""
            echo -e "${BOLD}💡 Platform Optimization Tip:${RESET}"
            echo -e "${DIM}MXFP4 is specifically optimized for Blackwell architecture (DGX Spark)${RESET}"
            echo -e "${DIM}Prefer MXFP4 models over standard Q4_K_M for best performance${RESET}"
            echo ""
            ;;
    esac
}

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

# Fetch list of files with sizes from a repository using the tree API
# Output format: size<TAB>filename (one per line)
fetch_repo_files_with_sizes() {
    local repo="$1"

    local url="https://huggingface.co/api/models/${repo}/tree/main"
    local response
    response=$(curl -s "$url" 2>/dev/null)

    # Check for error
    if echo "$response" | grep -q '"error"'; then
        return 1
    fi

    # Extract top-level "size" and "path" pairs from JSON array
    # Strategy: split on {"type" to isolate each file entry, avoiding
    # nested lfs objects that also contain "size" fields
    echo "$response" | sed 's/{"type"/\n{"type"/g' | while IFS= read -r entry; do
        # Skip entries without path
        echo "$entry" | grep -q '"path"' || continue

        local path
        path=$(echo "$entry" | grep -o '"path":"[^"]*"' | sed 's/"path":"//;s/"$//')

        # Get the first "size" before any "lfs" block (top-level size)
        local size
        size=$(echo "$entry" | sed 's/"lfs":.*//' | grep -o '"size":[0-9]*' | head -1 | sed 's/"size"://')

        if [ -n "$path" ] && [ -n "$size" ]; then
            printf '%s\t%s\n' "$size" "$path"
        fi
    done
}

# Get HuggingFace cache directory
get_hf_cache_dir() {
    # Use HF_HOME if set, otherwise use standard location
    local hf_home="${HF_HOME:-$HOME/.cache/huggingface}"
    echo "${hf_home}/hub"
}

# Initialize HuggingFace cache directory
init_hf_cache() {
    local cache_dir
    cache_dir=$(get_hf_cache_dir)
    mkdir -p "$cache_dir"
}

# Background progress monitor for curl downloads
# Checks file size on disk and displays progress
_curl_download_monitor() {
    local file_path="$1"
    local total_size="$2"
    local total_str="$3"

    while true; do
        sleep 1
        if [ -f "$file_path" ]; then
            # Get current file size (macOS stat vs Linux stat)
            local current_size
            current_size=$(stat -f%z "$file_path" 2>/dev/null || stat -c%s "$file_path" 2>/dev/null || echo 0)
            if [ "$current_size" -gt 0 ] 2>/dev/null; then
                local dl_str
                dl_str=$(format_size "$current_size")
                local pct
                pct=$((current_size * 100 / total_size))
                printf "\r  %s / %s  (%d%%)" "$dl_str" "$total_str" "$pct" >&2
            fi
        fi
    done
}

# Download a file using curl with size progress
# Usage: curl_download <url> <output_path> [total_size_bytes]
curl_download() {
    local url="$1"
    local output_path="$2"
    local total_size="${3:-}"

    # Create output directory if needed
    local output_dir
    output_dir=$(dirname "$output_path")
    mkdir -p "$output_dir"

    if [ -n "$total_size" ] && [ "$total_size" -gt 0 ] 2>/dev/null; then
        local total_str
        total_str=$(format_size "$total_size")

        # Start a background progress monitor that checks actual file size on disk
        _curl_download_monitor "$output_path" "$total_size" "$total_str" &
        local monitor_pid=$!

        # Ensure monitor is killed on interrupt (Ctrl+C) or exit
        trap 'kill '"$monitor_pid"' 2>/dev/null || true; wait '"$monitor_pid"' 2>/dev/null || true; printf "\r%*s\r" 40 "" >&2; trap - INT TERM EXIT' INT TERM EXIT

        # Download with curl - follow redirects, support resume, silent mode
        local curl_exit=0
        curl -L -s --continue-at - --output "$output_path" "$url" || curl_exit=$?

        # Clean up monitor and reset trap
        kill "$monitor_pid" 2>/dev/null || true
        wait "$monitor_pid" 2>/dev/null || true
        trap - INT TERM EXIT

        if [ "$curl_exit" -eq 0 ]; then
            printf "\r  %s / %s  (100%%)    \n" "$total_str" "$total_str" >&2
            return 0
        else
            printf "\r%*s\r" 40 "" >&2
            rm -f "$output_path"
            return 1
        fi
    else
        # No size info, use default curl progress bar
        if curl -L --progress-bar --continue-at - --output "$output_path" "$url"; then
            return 0
        else
            rm -f "$output_path"
            return 1
        fi
    fi
}

# Build HuggingFace CDN URL
build_hf_url() {
    local repo="$1"
    local filename="$2"

    # URL encode the repo and filename (simple encoding for common chars)
    # HuggingFace URLs use forward slashes for repos and filenames
    echo "https://huggingface.co/${repo}/resolve/main/${filename}"
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

    # Show platform-specific recommendations
    show_quant_recommendations

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

    # Show download method info before downloading
    show_download_method_info

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

    # Show download method info at the start
    show_download_method_info

    do_download "$repo"
}

# Look up file size from size data (size_data format: size<TAB>filename per line)
# Returns the size in bytes, or empty string if not found
lookup_file_size() {
    local size_data="$1"
    local filename="$2"

    echo "$size_data" | grep "	${filename}$" | head -1 | cut -f1
}

# Compute total size for a list of files from size data
# Returns total bytes
compute_group_size() {
    local size_data="$1"
    local files="$2"
    local total=0

    while IFS= read -r file; do
        [ -z "$file" ] && continue
        local sz
        sz=$(lookup_file_size "$size_data" "$file")
        if [ -n "$sz" ]; then
            total=$((total + sz))
        fi
    done <<<"$files"

    echo "$total"
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

    # Initialize HuggingFace cache directory
    init_hf_cache

    log_info "Fetching file list from $repo..."

    # Fetch files with sizes from tree API
    local size_data
    size_data=$(fetch_repo_files_with_sizes "$repo")

    if [ -z "$size_data" ]; then
        die "Could not fetch files from repository: $repo"
    fi

    # Extract just filenames (second column)
    local files
    files=$(echo "$size_data" | cut -f2)

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

            # Compute total size for the group
            local group_size
            group_size=$(compute_group_size "$size_data" "$group_files")
            local size_str=""
            if [ "$group_size" -gt 0 ] 2>/dev/null; then
                size_str=" $(format_size "$group_size")"
            fi

            # Extract quant type for display
            local quant_type
            quant_type=$(echo "$group" | grep -oiE 'MXFP4|UD-[UI]?Q[0-9]+_K_[A-Za-z]+|[UI]?Q[0-9]+_K_[A-Za-z]+|[UI]?Q[0-9]+_[0-9A-Za-z]+|[UI]?Q[0-9]+_K|[BF]+16' | head -1 || echo "unknown")

            QUANT_OPTIONS[$i]="$group"
            QUANT_FILES[$i]="$group_files"

            if [ "$file_count" -gt 1 ]; then
                echo -e "  ${CYAN}$i)${RESET} $quant_type ${DIM}($file_count parts,${size_str})${RESET}"
            else
                echo -e "  ${CYAN}$i)${RESET} $group ${DIM}(${size_str})${RESET}"
            fi
            ((i++))
        done <<<"$groups"
    else
        # Single files, show directly with size
        while IFS= read -r file; do
            [ -z "$file" ] && continue
            QUANT_OPTIONS[$i]="$file"
            QUANT_FILES[$i]="$file"

            # Look up file size
            local file_size
            file_size=$(lookup_file_size "$size_data" "$file")
            local size_str=""
            if [ -n "$file_size" ] && [ "$file_size" -gt 0 ] 2>/dev/null; then
                size_str=" ($(format_size "$file_size"))"
            fi

            echo -e "  ${CYAN}$i)${RESET} $file${DIM}${size_str}${RESET}"
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
        quant_type=$(echo "$rec_opt" | grep -oiE 'MXFP4|[UI]?Q[0-9]+_K_[A-Za-z]+|[UI]?Q[0-9]+_[0-9A-Za-z]+|[UI]?Q[0-9]+_K|[BF]+16' | head -1 || echo "recommended")
        log_info "Recommended: $quant_type"
        echo ""

        if confirm "Download recommended ($quant_type)?" "y"; then
            download_files "$repo" "${QUANT_FILES[$recommended_idx]}" "$size_data"
            return
        fi
    fi

    # Manual selection
    read -rp "Select quantization to download (1-$((i - 1))): " choice

    if ! [[ "$choice" =~ ^[0-9]+$ ]] || [ "$choice" -lt 1 ] || [ "$choice" -ge $i ]; then
        die "Invalid selection"
    fi

    download_files "$repo" "${QUANT_FILES[$choice]}" "$size_data"
}

# Download a specific file
download_file() {
    local repo="$1"
    local filename="$2"

    echo ""
    log_info "Downloading $filename..."
    echo ""

    # Build cache path
    local cache_dir
    cache_dir=$(get_hf_cache_dir)
    local model_dir="${cache_dir}/models--${repo/\//:}"
    local output_path="${model_dir}/snapshots/main/${filename}"

    # Build download URL
    local url
    url=$(build_hf_url "$repo" "$filename")

    # Download file
    if curl_download "$url" "$output_path"; then
        echo ""
        log_success "Download complete!"
        echo ""
        echo "Model saved to:"
        echo "  $output_path"
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
# Usage: download_files <repo> <files> [size_data]
download_files() {
    local repo="$1"
    local files="$2"
    local size_data="${3:-}"

    # Count files
    local file_count
    file_count=$(echo "$files" | grep -c '.' || echo 0)

    # Compute total download size
    local total_download_size=0
    if [ -n "$size_data" ]; then
        total_download_size=$(compute_group_size "$size_data" "$files")
    fi

    echo ""
    if [ "$file_count" -gt 1 ]; then
        if [ "$total_download_size" -gt 0 ] 2>/dev/null; then
            log_info "Downloading $file_count files ($(format_size "$total_download_size"))..."
        else
            log_info "Downloading $file_count files..."
        fi
    else
        if [ "$total_download_size" -gt 0 ] 2>/dev/null; then
            log_info "Downloading ($(format_size "$total_download_size"))..."
        else
            log_info "Downloading..."
        fi
    fi
    echo ""

    local success=true
    local downloaded=0

    # Build cache path
    local cache_dir
    cache_dir=$(get_hf_cache_dir)
    local model_dir="${cache_dir}/models--${repo/\//:}"

    while IFS= read -r file; do
        [ -z "$file" ] && continue

        # Look up individual file size
        local file_size=""
        if [ -n "$size_data" ]; then
            file_size=$(lookup_file_size "$size_data" "$file")
        fi

        if [ "$file_count" -gt 1 ]; then
            ((downloaded++))
            local file_size_str=""
            if [ -n "$file_size" ] && [ "$file_size" -gt 0 ] 2>/dev/null; then
                file_size_str=" ($(format_size "$file_size"))"
            fi
            echo -e "${DIM}[$downloaded/$file_count]${RESET} $file${DIM}${file_size_str}${RESET}"
        fi

        # Build output path
        local output_path="${model_dir}/snapshots/main/${file}"

        # Build download URL
        local url
        url=$(build_hf_url "$repo" "$file")

        # Download file with size info
        if ! curl_download "$url" "$output_path" "$file_size"; then
            log_error "Failed to download: $file"
            success=false
            break
        fi
    done <<<"$files"

    if [ "$success" = true ]; then
        echo ""
        log_success "Download complete!"
        echo ""
        echo "Models saved to:"
        echo "  $model_dir/snapshots/main/"
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
