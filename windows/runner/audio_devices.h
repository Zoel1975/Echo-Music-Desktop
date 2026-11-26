#ifndef RUNNER_AUDIO_DEVICES_H_
#define RUNNER_AUDIO_DEVICES_H_

#include <flutter/binary_messenger.h>

// Registers the `com.echo/audio_devices` MethodChannel used by
// AudioDeviceService to enumerate and select Windows playback endpoints.
void RegisterAudioDeviceChannel(flutter::BinaryMessenger* messenger);

#endif  // RUNNER_AUDIO_DEVICES_H_
