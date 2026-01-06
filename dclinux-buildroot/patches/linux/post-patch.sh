#!/bin/bash
# Post-patch script to fix AICA sound driver for kernel 4.19
# This adds sync_stop logic to the close callback and removes the .sync_stop member

set -e

AICA_FILE="sound/sh/aica.c"

echo "Applying AICA driver fix for kernel 4.19..."

# Add synchronization cleanup to close callback (after the dreamcastcard assignment)
sed -i '/struct snd_card_aica \*dreamcastcard = substream->pcm->private_data;/a\\n\t/* Synchronize cleanup (sync_stop logic for kernel 4.19 compat) */\n\tdel_timer_sync(\&dreamcastcard->timer);\n\tcancel_work_sync(\&dreamcastcard->spu_dma_work);\n' "$AICA_FILE"

# Remove the .sync_stop line from the ops structure
sed -i '/\.sync_stop = snd_aicapcm_pcm_sync_stop,/d' "$AICA_FILE"

echo "AICA driver fix applied successfully!"
