#!/bin/bash
# llm-cli: Statistics tracking
# Track usage statistics with JSON storage

# Initialize stats file
init_stats() {
    init_directories

    if [ ! -f "$STATS_FILE" ]; then
        local now
        now=$(get_timestamp)

        if has_jq; then
            cat > "$STATS_FILE" << EOF
{
  "version": "1.0",
  "created_at": "$now",
  "summary": {
    "total_sessions": 0,
    "total_time_seconds": 0,
    "total_benchmarks": 0
  },
  "models_used": {},
  "sessions": [],
  "benchmarks": []
}
EOF
        else
            # Simple fallback format
            cat > "$STATS_FILE" << EOF
{
  "version": "1.0",
  "created_at": "$now",
  "total_sessions": 0,
  "total_time_seconds": 0,
  "total_benchmarks": 0
}
EOF
        fi
    fi

    # Also ensure sessions log exists for fallback
    touch "$SESSIONS_LOG"
}

# Record a chat session
record_session() {
    local model_name="$1"
    local duration="${2:-0}"

    init_stats

    local now
    now=$(get_timestamp)
    local session_id
    session_id=$(generate_id)

    if has_jq; then
        # Full JSON update with jq
        local temp_file="${STATS_FILE}.tmp"

        jq --arg model "$model_name" \
           --arg time "$now" \
           --arg id "$session_id" \
           --argjson dur "$duration" \
           '.summary.total_sessions += 1 |
            .summary.total_time_seconds += $dur |
            .models_used[$model] = ((.models_used[$model] // {sessions: 0, time_seconds: 0}) |
                .sessions += 1 | .time_seconds += $dur | .last_used = $time) |
            .sessions += [{id: $id, model: $model, started_at: $time, duration_seconds: $dur}]' \
           "$STATS_FILE" > "$temp_file" && mv "$temp_file" "$STATS_FILE"
    else
        # Fallback: append to log file
        echo "SESSION|$now|$session_id|$model_name|$duration" >> "$SESSIONS_LOG"

        # Update simple counters in JSON using sed
        local current_sessions current_time
        current_sessions=$(grep -o '"total_sessions": [0-9]*' "$STATS_FILE" | grep -o '[0-9]*' || echo 0)
        current_time=$(grep -o '"total_time_seconds": [0-9]*' "$STATS_FILE" | grep -o '[0-9]*' || echo 0)

        local new_sessions=$((current_sessions + 1))
        local new_time=$((current_time + duration))

        sed -i.bak "s/\"total_sessions\": $current_sessions/\"total_sessions\": $new_sessions/" "$STATS_FILE"
        sed -i.bak "s/\"total_time_seconds\": $current_time/\"total_time_seconds\": $new_time/" "$STATS_FILE"
        rm -f "${STATS_FILE}.bak"
    fi

    log_debug "Session recorded: $model_name (${duration}s)"
}

# Record a benchmark result
record_benchmark_result() {
    local model_name="$1"
    local pp_score="${2:-}"
    local tg_score="${3:-}"

    init_stats

    local now
    now=$(get_timestamp)
    local today
    today=$(date +%Y-%m-%d)

    if has_jq; then
        local temp_file="${STATS_FILE}.tmp"

        jq --arg model "$model_name" \
           --arg date "$today" \
           --arg time "$now" \
           '.summary.total_benchmarks += 1 |
            .benchmarks += [{model: $model, date: $date, timestamp: $time}]' \
           "$STATS_FILE" > "$temp_file" && mv "$temp_file" "$STATS_FILE"
    else
        # Fallback: append to log
        echo "BENCHMARK|$now|$model_name|$pp_score|$tg_score" >> "$SESSIONS_LOG"

        # Update counter
        local current
        current=$(grep -o '"total_benchmarks": [0-9]*' "$STATS_FILE" | grep -o '[0-9]*' || echo 0)
        local new_count=$((current + 1))

        sed -i.bak "s/\"total_benchmarks\": $current/\"total_benchmarks\": $new_count/" "$STATS_FILE"
        rm -f "${STATS_FILE}.bak"
    fi

    log_debug "Benchmark recorded: $model_name"
}

# Stats command
cmd_stats() {
    local subcmd="${1:-show}"

    case "$subcmd" in
        --clear|-c|clear)
            clear_stats
            ;;
        --help|-h)
            echo "Usage: llm-cli stats [options]"
            echo ""
            echo "Options:"
            echo "  (none)      Show usage statistics"
            echo "  --clear     Clear all statistics"
            echo "  --help      Show this help"
            ;;
        *)
            show_stats
            ;;
    esac
}

# Display statistics
show_stats() {
    init_stats

    print_header "Usage Statistics"
    echo ""

    if has_jq; then
        show_stats_full
    else
        show_stats_basic
    fi
}

# Full stats display (with jq)
show_stats_full() {
    local stats
    stats=$(cat "$STATS_FILE")

    # Summary
    local total_sessions total_time total_benchmarks created_at
    total_sessions=$(echo "$stats" | jq -r '.summary.total_sessions // 0')
    total_time=$(echo "$stats" | jq -r '.summary.total_time_seconds // 0')
    total_benchmarks=$(echo "$stats" | jq -r '.summary.total_benchmarks // 0')
    created_at=$(echo "$stats" | jq -r '.created_at // "unknown"')

    # Format time
    local hours=$((total_time / 3600))
    local mins=$(((total_time % 3600) / 60))
    local secs=$((total_time % 60))
    local time_fmt="${hours}h ${mins}m ${secs}s"

    echo -e "${BOLD}Summary${RESET}"
    echo "  Total Sessions:   $total_sessions"
    echo "  Total Time:       $time_fmt"
    echo "  Total Benchmarks: $total_benchmarks"
    echo "  Tracking Since:   $created_at"
    echo ""

    # Models used
    local models_used
    models_used=$(echo "$stats" | jq -r '.models_used | keys[]' 2>/dev/null)

    if [ -n "$models_used" ]; then
        echo -e "${BOLD}Models Used${RESET}"
        echo ""
        printf "  %-45s %10s %12s\n" "Model" "Sessions" "Time"
        print_line "-" 70
        echo ""

        while IFS= read -r model; do
            local sessions model_time last_used
            sessions=$(echo "$stats" | jq -r ".models_used[\"$model\"].sessions // 0")
            model_time=$(echo "$stats" | jq -r ".models_used[\"$model\"].time_seconds // 0")
            last_used=$(echo "$stats" | jq -r ".models_used[\"$model\"].last_used // \"\"")

            # Format model time
            local m_hrs=$((model_time / 3600))
            local m_mins=$(((model_time % 3600) / 60))
            local m_time_fmt="${m_hrs}h ${m_mins}m"

            # Truncate model name
            local display_name="$model"
            if [ ${#display_name} -gt 43 ]; then
                display_name="${display_name:0:40}..."
            fi

            printf "  %-45s %10s %12s\n" "$display_name" "$sessions" "$m_time_fmt"
        done <<< "$models_used"
        echo ""
    fi

    # Recent sessions
    local session_count
    session_count=$(echo "$stats" | jq '.sessions | length')

    if [ "$session_count" -gt 0 ]; then
        echo -e "${BOLD}Recent Sessions${RESET} (last 5)"
        echo ""

        echo "$stats" | jq -r '.sessions | reverse | .[0:5][] |
            "  \(.started_at | split("T")[0]) - \(.model) (\(.duration_seconds)s)"' 2>/dev/null || true
        echo ""
    fi

    # Data location
    echo -e "${DIM}Stats file: $STATS_FILE${RESET}"
}

# Basic stats display (without jq)
show_stats_basic() {
    log_warn "jq not installed. Showing basic statistics only."
    log_warn "Install jq for full statistics: brew install jq"
    echo ""

    local total_sessions total_time total_benchmarks
    total_sessions=$(grep -o '"total_sessions": [0-9]*' "$STATS_FILE" 2>/dev/null | grep -o '[0-9]*' || echo 0)
    total_time=$(grep -o '"total_time_seconds": [0-9]*' "$STATS_FILE" 2>/dev/null | grep -o '[0-9]*' || echo 0)
    total_benchmarks=$(grep -o '"total_benchmarks": [0-9]*' "$STATS_FILE" 2>/dev/null | grep -o '[0-9]*' || echo 0)

    # Format time
    local hours=$((total_time / 3600))
    local mins=$(((total_time % 3600) / 60))
    local time_fmt="${hours}h ${mins}m"

    echo -e "${BOLD}Summary${RESET}"
    echo "  Total Sessions:   $total_sessions"
    echo "  Total Time:       $time_fmt"
    echo "  Total Benchmarks: $total_benchmarks"
    echo ""

    # Show log file entries if available
    if [ -f "$SESSIONS_LOG" ] && [ -s "$SESSIONS_LOG" ]; then
        echo -e "${BOLD}Recent Activity${RESET} (last 5)"
        tail -5 "$SESSIONS_LOG" | while IFS='|' read -r type timestamp id model duration; do
            local date="${timestamp%%T*}"
            if [ "$type" = "SESSION" ]; then
                echo "  $date - Chat: $model (${duration}s)"
            elif [ "$type" = "BENCHMARK" ]; then
                echo "  $date - Benchmark: $model"
            fi
        done
        echo ""
    fi

    echo -e "${DIM}Stats file: $STATS_FILE${RESET}"
}

# Clear all statistics
clear_stats() {
    if [ ! -f "$STATS_FILE" ] && [ ! -f "$SESSIONS_LOG" ]; then
        echo "No statistics to clear."
        return
    fi

    echo ""
    echo "This will delete all usage statistics."
    echo ""

    if confirm "Clear all statistics?"; then
        rm -f "$STATS_FILE" "$SESSIONS_LOG"
        init_stats
        log_success "Statistics cleared."
    else
        echo "Cancelled."
    fi
}
