#!/bin/bash
set -euo pipefail

PROJECT_ID="${GCP_PROJECT_ID:-collab-tools-prod}"
REGION="australia-southeast1"
SERVICE="collaboration-tools"
REPO="$REGION-docker.pkg.dev/$PROJECT_ID/collab-tools"

TAG="${GITHUB_SHA:-$(git rev-parse HEAD)}"
IMAGE="$REPO/app:$TAG"

echo "==> Building image: $IMAGE"
docker build -t "$IMAGE" .

echo "==> Pushing image to Artifact Registry"
docker push "$IMAGE"

echo "==> Deploying to Cloud Run"
gcloud run deploy "$SERVICE" \
  --image="$IMAGE" \
  --region="$REGION" \
  --project="$PROJECT_ID" \
  --platform=managed \
  --allow-unauthenticated \
  --set-secrets="DATABASE_URL=db-url:latest,JWT_SECRET=jwt-secret:latest" \
  --min-instances=0 \
  --max-instances=3 \
  --memory=512Mi \
  --cpu=1 \
  --port=8080 \
  --timeout=600

echo "==> Deploy complete"
gcloud run services describe "$SERVICE" --region="$REGION" --project="$PROJECT_ID" --format="value(status.url)"
