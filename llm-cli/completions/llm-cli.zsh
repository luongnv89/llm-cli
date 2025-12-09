#compdef llm-cli
# llm-cli zsh completion
# Copy to ~/.local/share/zsh/site-functions/_llm-cli

_llm-cli() {
    local -a commands
    commands=(
        'search:Search HuggingFace for GGUF models'
        'download:Download a model from HuggingFace'
        'chat:Start conversation with a model'
        'models:Model management commands'
        'bench:Benchmark models'
        'stats:Show usage statistics'
        'config:Show/edit configuration'
        'help:Show help message'
    )

    local -a models_commands
    models_commands=(
        'list:List all cached models'
        'info:Show detailed model info'
        'delete:Delete a cached model'
        'update:Update a cached model'
    )

    _arguments -C \
        '-h[Show help]' \
        '--help[Show help]' \
        '-v[Show version]' \
        '--version[Show version]' \
        '--no-color[Disable colored output]' \
        '1: :->command' \
        '*:: :->args'

    case $state in
        command)
            _describe -t commands 'llm-cli commands' commands
            ;;
        args)
            case $words[1] in
                search|s)
                    _message 'search query'
                    ;;
                download|d|get)
                    _message 'repository (e.g., bartowski/Llama-3.2-3B-Instruct-GGUF)'
                    ;;
                chat|c|run)
                    _message 'model number (optional)'
                    ;;
                models|model)
                    _describe -t models_commands 'models subcommands' models_commands
                    ;;
                bench|benchmark)
                    _arguments \
                        '--all[Benchmark all models]' \
                        '--batch[Benchmark specific models]:models:' \
                        '--reports[List saved benchmark reports]' \
                        '--help[Show help]' \
                        '*:model number:'
                    ;;
                stats|statistics)
                    _arguments \
                        '--clear[Clear all statistics]' \
                        '--help[Show help]'
                    ;;
                config)
                    _arguments \
                        '--edit[Edit configuration file]'
                    ;;
            esac
            ;;
    esac
}

_llm-cli "$@"
