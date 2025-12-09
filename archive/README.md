# Archive

This folder contains deprecated scripts that have been replaced by the modular `llm-cli` tool.

## Contents

- **run-llm.sh** - Original monolithic script (722 lines). Replaced by `llm-cli/` which provides the same functionality in a modular, maintainable structure.

## Migration

If you were using `run-llm.sh`, switch to `llm-cli`:

```bash
# Install the new tool
cd ../llm-cli
./install.sh

# The new commands
llm-cli search <query>    # was: ./run-llm.sh (then select search)
llm-cli download <repo>   # was: ./run-llm.sh (then select download)
llm-cli chat              # was: ./run-llm.sh (then select run)
llm-cli bench             # was: ./run-llm.sh (then select benchmark)
llm-cli models list       # was: ./run-llm.sh --list
```

See [../llm-cli/README.md](../llm-cli/README.md) for full documentation.
