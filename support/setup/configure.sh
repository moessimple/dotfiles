#!/bin/bash

brew services start mailpit 2>/dev/null || true
brew services start meilisearch 2>/dev/null || true
brew services start ollama 2>/dev/null || true
