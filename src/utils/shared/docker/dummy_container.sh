#!/bin/bash

# Check if an image name was provided
if [ -z "$1" ]; then
  echo "Usage: $0 <image_name:tag>"
  echo "Example: $0 my-critical-image:latest"
  exit 1
fi

# Capture the image name (including optional tag) from the argument
IMAGE_NAME=$1

# Generate a unique dummy container name based on the image name
# Replace special characters (like ":" and "/") with dashes "-" to create a valid container name
DUMMY_CONTAINER_NAME="dummy-$(echo $IMAGE_NAME | sed 's/[:\/]/-/g')"

# Step 1: Check if the image exists
echo "Checking if the image '$IMAGE_NAME' exists..."
docker image inspect $IMAGE_NAME > /dev/null 2>&1

if [ $? -ne 0 ]; then
  echo "Error: Image '$IMAGE_NAME' not found. Make sure it exists."
  exit 1
fi

# Step 2: Check if a dummy container for the image already exists
EXISTING_CONTAINER=$(docker ps -a --filter "name=$DUMMY_CONTAINER_NAME" --format "{{.Names}}")
if [ "$EXISTING_CONTAINER" == "$DUMMY_CONTAINER_NAME" ]; then
  echo "A dummy container named '$DUMMY_CONTAINER_NAME' already exists. No need to create it."
  exit 0
fi

# Step 3: Create the dummy container using the provided image
echo "Creating a dummy container named '$DUMMY_CONTAINER_NAME' for image: $IMAGE_NAME"
docker create --name $DUMMY_CONTAINER_NAME $IMAGE_NAME > /dev/null 2>&1

if [ $? -eq 0 ]; then
  echo "Success: Dummy container created using image '$IMAGE_NAME' with name '$DUMMY_CONTAINER_NAME'."
else
  echo "Error: Failed to create dummy container. Check Docker for issues or conflicts."
fi
