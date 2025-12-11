# Implementation Tasks

## 1. Core Curl Download Implementation
- [ ] 1.1 Create `curl_download()` function with direct URL download
- [ ] 1.2 Implement proper error handling and HTTP status checking
- [ ] 1.3 Add progress tracking (curl --progress-bar)
- [ ] 1.4 Handle redirects and CDN resolution

## 2. Cache Directory Management
- [ ] 2.1 Implement HuggingFace cache directory creation
- [ ] 2.2 Ensure compatibility with standard HuggingFace cache structure
- [ ] 2.3 Add cache directory cleanup utilities (optional)

## 3. Replace huggingface-cli Usage
- [ ] 3.1 Replace `download_file()` implementation with curl
- [ ] 3.2 Replace `download_files()` implementation with curl loop
- [ ] 3.3 Update `do_download()` to remove huggingface-cli check
- [ ] 3.4 Update error messages to reflect new approach

## 4. Documentation Updates
- [ ] 4.1 Update README.md installation instructions
- [ ] 4.2 Remove huggingface-cli from requirements/dependencies
- [ ] 4.3 Update help text to remove huggingface-cli references
- [ ] 4.4 Document cache directory location in documentation

## 5. Testing & Validation
- [ ] 5.1 Test single file download
- [ ] 5.2 Test multi-part/split model download
- [ ] 5.3 Test on macOS (Apple Silicon)
- [ ] 5.4 Test on Linux (with/without NVIDIA)
- [ ] 5.5 Test with non-existent repository (error handling)
- [ ] 5.6 Test with network interruption recovery
- [ ] 5.7 Verify cached models are accessible
- [ ] 5.8 Verify Bash 3.2 compatibility
