FROM node:20-slim

# Install gosu for privilege dropping in entrypoint
RUN apt-get update && apt-get install -y --no-install-recommends gosu && rm -rf /var/lib/apt/lists/*

# Create a non-root user (required: Claude CLI refuses --dangerously-skip-permissions as root)
RUN groupadd -r paperclip && useradd -r -g paperclip -m -d /home/paperclip -s /bin/bash paperclip

# Create the paperclip home directory (Railway volume mount point)
RUN mkdir -p /paperclip && chown -R paperclip:paperclip /paperclip

WORKDIR /app

# Copy package files and install dependencies
COPY package.json ./
RUN npm install --omit=dev

# Copy application code
COPY . .

# Give ownership of everything to the non-root user
RUN chown -R paperclip:paperclip /app /home/paperclip

# Install OpenCode CLI globally
RUN npm install --global opencode-ai

# Create OpenCode config directory for paperclip user and write provider config
RUN mkdir -p /home/paperclip/.config/opencode
RUN printf '{\n  "$schema": "https://opencode.ai/config.json",\n  "provider": {\n    "ollama": {\n      "npm": "@ai-sdk/openai-compatible",\n      "name": "Ollama (Railway internal)",\n      "options": {\n        "baseURL": "http://ollama.railway.internal:11434/v1"\n      },\n      "models": {\n        "qwen2.5-coder:14b": {"name": "Qwen2.5 Coder 14B"},\n      "qwen2.5:3b": {"name": "Qwen2.5 3B"},\n      "qwen3:8b": {"name": "Qwen3 8B"}\n      }\n    }\n  }\n}\n' > /home/paperclip/.config/opencode/config.json
RUN chown -R paperclip:paperclip /home/paperclip/.config

# Copy and set up entrypoint (fixes volume mount ownership at runtime)
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Railway injects PORT at runtime (default 3100)
ENV PORT=3100
EXPOSE 3100

# Entrypoint runs as root to fix volume permissions, then drops to paperclip user
ENTRYPOINT ["/entrypoint.sh"]
CMD ["npm", "start"]
