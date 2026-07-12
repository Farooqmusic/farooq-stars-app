package com.farooqstars.app

// just_audio_background requires the main activity to be AudioServiceActivity
// (it extends FlutterActivity internally, but also connects the background
// audio service to the same Flutter engine). With a plain FlutterActivity,
// play/pause commands never reach the audio engine on Android, so no song
// plays — neither streaming nor offline. iOS is unaffected by this class.
import com.ryanheise.audioservice.AudioServiceActivity

class MainActivity : AudioServiceActivity()
