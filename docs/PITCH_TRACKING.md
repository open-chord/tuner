# Pitch tracking

OpenTuner tunes one plucked string at a time. The microphone uses iOS measurement mode and processes 4,096-sample frames without uploading audio.

1. `PitchDetector` calculates YIN's cumulative mean normalized difference function over the supported frequency range. Local minima are pitch candidates, not a single verdict. Parabolic interpolation avoids integer-lag jumps in the cents display.
2. A small Goertzel spectral check rejects candidate subharmonics that repeat well but have little energy at their own frequency. This check is note-independent; it does not contain special cases for E or B.
3. `PitchTracker` considers candidate quality and continuity across frames. It prefers the established pitch when another candidate only marginally wins, yet can move to a genuinely new note. Silence clears the track.
4. The selected frequency is compared with the active tuning preset. Manual string selection changes only the target, not the pitch estimate.

This follows the distinction in [YIN](https://doi.org/10.1121/1.1458024) between periodicity estimation and pitch selection, and the motivation behind [pYIN](https://webspace.eecs.qmul.ac.uk/s.e.dixon/pub/2014/MauchDixon-PYIN-ICASSP2014.pdf) to track multiple interpretations over time. This is an original, lightweight real-time implementation, not a copy of either algorithm or a full pYIN/HMM implementation.

The core tests cover all standard open strings plus low C, two sample rates, two input levels, two harmonic profiles, a 60 Hz background tone, octave ambiguity, clipping, and silence. A previous user-provided recording was also replayed locally through the pipeline; the recording is not stored in the repository. These checks do not replace validation on physical iPhones with different guitars, microphones, and amplifiers.
