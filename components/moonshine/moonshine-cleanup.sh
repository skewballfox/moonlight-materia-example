#!/bin/sh
# CleanupScript of the moonshine component. Materia runs it as root after the
# account's materia has stopped and removed the component. It keeps the
# account: nvidia-driver may still run as it, and its home holds Steam's
# library. Remove the account by hand once no component runs as it.
echo "moonshine removed; the moonshine account and its home are kept" >&2
