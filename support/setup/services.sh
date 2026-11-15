#!/bin/bash

brew services start mailpit || warn "Could not start mailpit"
brew services start meilisearch || warn "Could not start meilisearch"
brew services start ollama || warn "Could not start ollama"
