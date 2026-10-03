# Runtime for crop_to_aspect.py on the NAS.
#
# Deliberately holds no application code: the cropper is bind-mounted at run
# time so editing it needs no rebuild. That keeps this image stable, which
# matters because the monthly docker-prune wipes the builder cache.
FROM python:3.12-slim

RUN pip install --no-cache-dir \
      "pillow>=10.0" \
      "numpy>=1.26" \
      "opencv-python-headless>=4.8" \
      "pillow-heif>=0.15"

# YuNet face-detection weights, baked in so a run never touches the network.
# The load check fails the build if the download came back as an LFS pointer
# or a GitHub error page rather than the real model.
ARG YUNET_URL=https://github.com/opencv/opencv_zoo/raw/main/models/face_detection_yunet/face_detection_yunet_2023mar.onnx
RUN mkdir -p /opt/models \
 && python3 -c "import sys, urllib.request; urllib.request.urlretrieve(sys.argv[1], '/opt/models/face_detection_yunet_2023mar.onnx')" "$YUNET_URL" \
 && python3 -c "import cv2; cv2.FaceDetectorYN.create('/opt/models/face_detection_yunet_2023mar.onnx', '', (320, 320)); print('yunet loads')"

WORKDIR /work
ENTRYPOINT ["python3"]
