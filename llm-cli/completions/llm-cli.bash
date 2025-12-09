# llm-cli bash completion
# Source this file or copy to /etc/bash_completion.d/

_llm_cli() {
    local cur prev words cword
    _init_completion || return

    local commands="search download chat models bench stats config help"
    local models_subcmds="list info delete update"
    local bench_opts="--all --batch --reports --help"

    case "${words[1]}" in
        search|s)
            # No completion for search query
            return
            ;;
        download|d|get)
            # No completion for repo name
            return
            ;;
        chat|c|run)
            # Complete with model numbers (would need dynamic lookup)
            COMPREPLY=( $(compgen -W "1 2 3 4 5" -- "$cur") )
            return
            ;;
        models|model)
            if [ $cword -eq 2 ]; then
                COMPREPLY=( $(compgen -W "$models_subcmds" -- "$cur") )
            fi
            return
            ;;
        bench|benchmark)
            if [[ "$cur" == -* ]]; then
                COMPREPLY=( $(compgen -W "$bench_opts" -- "$cur") )
            else
                COMPREPLY=( $(compgen -W "1 2 3 4 5 --all --batch --reports" -- "$cur") )
            fi
            return
            ;;
        stats|statistics)
            COMPREPLY=( $(compgen -W "--clear --help" -- "$cur") )
            return
            ;;
        config)
            COMPREPLY=( $(compgen -W "--edit" -- "$cur") )
            return
            ;;
    esac

    # Top-level commands
    if [ $cword -eq 1 ]; then
        if [[ "$cur" == -* ]]; then
            COMPREPLY=( $(compgen -W "--help --version --no-color" -- "$cur") )
        else
            COMPREPLY=( $(compgen -W "$commands" -- "$cur") )
        fi
    fi
}

complete -F _llm_cli llm-cli
