#!/usr/bin/env bash
set -Eeuo pipefail

# Ask for the image name when running, or use a default
IMAGE_NAME="${1:-developmi/hardened-wp}"

if [[ ! "${IMAGE_NAME}" =~ ^[a-z0-9._/-]+(:[A-Za-z0-9._-]+)?$ ]]; then
	echo "❌ Invalid image name: ${IMAGE_NAME}"
	echo "Expected format: repo/name[:tag]"
	exit 1
fi

echo "🏗️ Building production image: $IMAGE_NAME ..."

if [ ! -f Caddyfile ]; then
	echo "⚠️ Caddyfile not found, copying from Caddyfile.example..."
	cp Caddyfile.example Caddyfile
fi

# Build the image using the main Dockerfile
docker build --pull -t "${IMAGE_NAME}" -f Dockerfile .

echo "✅ Image $IMAGE_NAME built successfully."
echo "You can try it with: docker run --rm -p 8080:8080 --env-file .env $IMAGE_NAME"