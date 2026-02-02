docker buildx build --no-cache \
  --platform=linux/amd64 \
  --target artifact \
  --output type=local,dest=./out \
  .
