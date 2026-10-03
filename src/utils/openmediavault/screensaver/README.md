# screensaver-crop (openmediavault)

Fits the screensaver paintings to the tablet's 16:10 panel so the slideshow has
no black bars, and keeps the output in step with the source directory.

- `crop_to_aspect.py` — the cropper. Smart-crops when at least 70% of the
  composition survives, otherwise scales to fit and fills the remainder with a
  blurred zoom of the image itself. A saliency map picks the crop window and
  any faces YuNet finds are kept whole inside it. Reads HEIC as well as the
  usual formats; always writes JPEG.
- `Dockerfile` — pillow, numpy, opencv-python-headless and pillow-heif on
  python:3.12-slim. The host is Debian buster with Python 3.7 and none of
  these, so the job runs in a container. The image carries no application code
  (the cropper is bind-mounted) but does bake in the YuNet weights, so a run
  never touches the network. The build fails if the download is not a loadable
  model.
- `screensaver_crop.sh` — cron entry point. Incremental and self-healing
  (rebuilds the image if it has gone missing), silent on ticks that change
  nothing.

## Deployment

Not staged by `make install` — this host keeps its Docker projects outside the
repo, the same way `~/Projects/nginx` is unmanaged. Deploy by hand:

    scp Dockerfile crop_to_aspect.py screensaver_crop.sh \
        openmediavault.local:/home/sthinds/Projects/screensaver-crop/

Schedule (sthinds crontab, not /etc/cron.d, so it needs no root):

    */15 * * * * flock -n /tmp/screensaver-crop.lock \
      /home/sthinds/Projects/screensaver-crop/screensaver_crop.sh \
      >> /home/sthinds/.cache/.workflow/screensaver-crop.log 2>&1

## Face detection

YuNet (`cv2.FaceDetectorYN`, ~230KB ONNX) runs on CPU in a few milliseconds
per image — no GPU involved; the host's Intel HD 530 is there for Plex. The
weights are searched next to `crop_to_aspect.py`, then `/opt/models`, then
`$SCREENSAVER_FACE_MODEL`. When none is found the cropper says so and frames
on saliency alone, which is close to as good: over the 24 paintings here,
faces changed the crop for exactly one (Bruegel's *Tower of Babel*, where they
kept Nimrod's group off the bottom edge). It earns its place on photographs,
where a face against a plain wall carries little saliency of its own.

## Serving

The `screensaver` container (`~/Projects/nginx`, port 8092) mounts the source
directory at `/usr/share/nginx/html` for `index.html`, and the processed
directory at `/usr/share/nginx/files` for the `/files/` listing the slideshow
reads.
