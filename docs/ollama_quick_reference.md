# Ollama GPU Quick Reference Guide

## Installation & Setup

### Install Ollama
```bash
curl -fsSL https://ollama.ai/install.sh | sh
```

### Enable GPU in Ollama Service
```bash
# Create service override directory
sudo mkdir -p /etc/systemd/system/ollama.service.d

# Create GPU configuration file
sudo tee /etc/systemd/system/ollama.service.d/gpu.conf > /dev/null << 'EOF'
[Service]
Environment="CUDA_VISIBLE_DEVICES=0"
Environment="OLLAMA_NUM_GPU=-1"
Environment="OLLAMA_KEEP_ALIVE=24h"
Environment="OLLAMA_NUM_THREAD=32"
EOF

# Reload and restart
sudo systemctl daemon-reload
sudo systemctl restart ollama
```

### Make Ollama Accessible on Network
```bash
sudo tee /etc/systemd/system/ollama.service.d/network.conf > /dev/null << 'EOF'
[Service]
Environment="OLLAMA_HOST=0.0.0.0:11434"
EOF

sudo systemctl daemon-reload
sudo systemctl restart ollama
# Now accessible at: http://192.168.0.122:11434
```

## Model Management

### Pull a Model
```bash
ollama pull mistral           # 4.1B - Fast, recommended start
ollama pull llama2            # 7B/13B/70B - High quality
ollama pull neural-chat       # 7B - Chat optimized
ollama pull dolphin2.2        # 7B/13B - Very capable
```

### List Downloaded Models
```bash
ollama list
```

### Remove a Model
```bash
ollama rm mistral
```

### Run a Model
```bash
ollama run mistral
ollama run mistral "Explain machine learning"
```

## API Usage

### Generate Response (HTTP)
```bash
curl -X POST http://localhost:11434/api/generate \
  -H "Content-Type: application/json" \
  -d '{
    "model": "mistral",
    "prompt": "What is the capital of France?",
    "stream": false
  }'
```

### Streaming Response
```bash
curl -X POST http://localhost:11434/api/generate \
  -H "Content-Type: application/json" \
  -d '{
    "model": "mistral",
    "prompt": "Write a poem about AI",
    "stream": true
  }' | jq -r '.response'
```

### List Available Models (API)
```bash
curl http://localhost:11434/api/tags
```

### Check Ollama Status
```bash
curl http://localhost:11434/api/tags | jq .
```

## GPU Monitoring

### Real-time GPU Monitoring
```bash
watch -n 0.5 nvidia-smi
```

### Detailed GPU Stats
```bash
nvidia-smi --query-gpu=index,name,memory.total,memory.used,memory.free,utilization.gpu,temperature.gpu \
  --format=csv -l 1
```

### GPU Memory Usage Only
```bash
nvidia-smi --query-gpu=memory.used,memory.free --format=csv,noheader -l 1
```

### Log GPU Usage During Inference
```bash
# Terminal 1: Monitor GPU
watch -n 0.5 'date; nvidia-smi --query-gpu=memory.used,memory.free,utilization.gpu --format=csv,noheader'

# Terminal 2: Run inference
ollama run mistral "Your question here"
```

## Service Management

### Check Service Status
```bash
sudo systemctl status ollama
```

### Start/Stop/Restart Ollama
```bash
sudo systemctl start ollama
sudo systemctl stop ollama
sudo systemctl restart ollama
```

### Enable Auto-start on Boot
```bash
sudo systemctl enable ollama
```

### Check Ollama Logs
```bash
# Last 50 lines
sudo journalctl -u ollama -n 50

# Follow logs in real-time
sudo journalctl -u ollama -f

# Check for GPU-related messages
sudo journalctl -u ollama -f | grep -i cuda
```

## Performance Benchmarking

### Simple Benchmark
```bash
time ollama run mistral "Explain artificial intelligence in detail. Make it comprehensive and technical."
```

### Measure Tokens Per Second
```bash
cat > benchmark.sh << 'EOF'
#!/bin/bash
MODEL=${1:-mistral}
PROMPT="The history of artificial intelligence is fascinating. It began in the 1950s when pioneers like Alan Turing asked whether machines could think. Since then, AI has evolved dramatically, from expert systems to deep learning. Today, AI powers countless applications across healthcare, finance, transportation, and more. The future of AI promises even more remarkable developments."

echo "Benchmarking $MODEL..."
RESPONSE=$(curl -s http://localhost:11434/api/generate \
  -H "Content-Type: application/json" \
  -d "{\"model\":\"$MODEL\",\"prompt\":\"$PROMPT\",\"stream\":false}" 2>/dev/null)

TOKENS=$(echo "$RESPONSE" | jq '.eval_count // 0')
DURATION=$(echo "$RESPONSE" | jq '.eval_duration // 0')
TOKENS_PER_SEC=$(echo "scale=2; ($TOKENS * 1000000000) / $DURATION" | bc)

echo "Model: $MODEL"
echo "Tokens generated: $TOKENS"
echo "Time: ${DURATION}ns"
echo "Tokens/sec: $TOKENS_PER_SEC"
EOF

chmod +x benchmark.sh
./benchmark.sh mistral
```

## Troubleshooting

### GPU Not Detected
```bash
# Verify NVIDIA driver
nvidia-smi

# Check CUDA libraries
ldconfig -p | grep libcuda

# Reinstall CUDA
sudo apt-get install -y nvidia-cuda-toolkit

# Restart Ollama
sudo systemctl restart ollama
```

### Slow Performance (Likely CPU-only)
```bash
# Check if GPU is being used during inference
watch -n 0.5 nvidia-smi

# If GPU memory isn't increasing during inference, GPU isn't being used
# Try:
1. Restart Ollama: sudo systemctl restart ollama
2. Check logs: sudo journalctl -u ollama -f
3. Verify CUDA: nvidia-smi
4. Reinstall: curl -fsSL https://ollama.ai/install.sh | sh
```

### Out of Memory
```bash
# Reduce number of loaded models
OLLAMA_MAX_LOADED_MODELS=1 ollama serve

# Or reduce GPU layers usage
OLLAMA_NUM_GPU=50 ollama run mistral  # Use only 50 GPU layers instead of all
```

### Connection Refused
```bash
# Check if service is running
sudo systemctl status ollama

# Check if port is in use
sudo lsof -i :11434

# Force restart
sudo systemctl restart ollama
sleep 3
curl http://localhost:11434/api/tags
```

## Environment Variables Reference

| Variable | Default | Purpose |
|----------|---------|---------|
| `OLLAMA_NUM_GPU` | `-1` | GPU layers to use (-1 = all) |
| `OLLAMA_NUM_THREAD` | Auto | CPU threads for operations |
| `OLLAMA_KEEP_ALIVE` | `5m` | Time to keep models loaded |
| `OLLAMA_MAX_LOADED_MODELS` | `1` | Max models to load simultaneously |
| `CUDA_VISIBLE_DEVICES` | All | Which GPUs to use (0,1,2...) |
| `OLLAMA_HOST` | `127.0.0.1:11434` | Listen address and port |
| `OLLAMA_DEBUG` | `0` | Enable debug logging (0 or 1) |

## Docker Compose Commands

### Deploy Stack
```bash
docker-compose -f docker-compose-ollama-gpu.yml up -d
```

### Check Status
```bash
docker-compose -f docker-compose-ollama-gpu.yml ps
```

### View Logs
```bash
docker-compose -f docker-compose-ollama-gpu.yml logs -f ollama
docker-compose -f docker-compose-ollama-gpu.yml logs -f open-webui
```

### Stop Stack
```bash
docker-compose -f docker-compose-ollama-gpu.yml down
```

### Full Cleanup (remove volumes)
```bash
docker-compose -f docker-compose-ollama-gpu.yml down -v
```

## Performance Expectations (Grace Hopper)

| Model | Speed | Memory | Quality |
|-------|-------|--------|---------|
| Mistral 7B | ~100 tokens/sec | ~20GB | Good |
| Llama2 13B | ~60 tokens/sec | ~30GB | Excellent |
| Mistral 8x7B MoE | ~80 tokens/sec | ~50GB | Excellent |
| Dolphin 70B | ~30 tokens/sec | ~80GB | Outstanding |

Note: Your Grace Hopper has 96GB memory, so you can run even the largest models.

## Useful Aliases

Add to `~/.bashrc` or `~/.zshrc`:

```bash
alias ollama-status='sudo systemctl status ollama'
alias ollama-logs='sudo journalctl -u ollama -f'
alias ollama-restart='sudo systemctl restart ollama'
alias ollama-gpu='watch -n 0.5 nvidia-smi'
alias ollama-api='curl -s http://localhost:11434/api/tags | jq'
alias ollama-bench='bash /path/to/benchmark.sh'
```

Then reload:
```bash
source ~/.bashrc
```

Usage:
```bash
ollama-gpu           # Monitor GPU
ollama-logs          # Check logs
ollama-api          # Check running models
```
