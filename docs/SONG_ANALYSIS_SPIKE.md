# Song analysis: chord and rhythm discovery spike

Status: research proposal, not a shipped feature. This branch is independent of
the tuner input-stabilization work. No audio-analysis implementation or claim of
recognition quality is included here.

## User job

Import a recording and get an editable, time-aligned chord chart with a useful
rhythmic guide. This is **not** the same problem as the existing tuner: a tuner
estimates one dominant pitch, while a song may contain several notes and
instruments at once.

"Rhythm" has three distinct meanings:

1. Tempo and beat positions (BPM and a beat grid).
2. Audible attack/strum positions within a bar.
3. Guitar stroke direction (down/up), rests and accents.

We should not label beat tracking as a recovered strumming pattern. Direction
inference is a separate, harder task, especially for a complete band mix.

## Proposed first slice

Start with **imported, guitar-forward audio**, not live microphone analysis or
an arbitrary streaming-service song. Show a chord timeline, estimated tempo,
beat grid and possible attack markers. Let the user tap to correct a chord,
move a boundary or remove a false attack. Mark low-confidence spans as
"check this" rather than presenting guesses as fact. Keep processing local and
allow deleting the imported file and analysis. No account or upload.

Defer down/up strokes, automatic key/capo claims, song search, stem separation,
and polished export until measurements show they are viable. Full-mix songs
must be tested separately; success on solo acoustic guitar will not prove it.

## Candidate pipeline

1. Import a local audio file; decode, downmix and resample for analysis.
2. Extract a time-frequency representation, then pitch-class/chroma evidence.
3. Score a limited vocabulary of chord roots and qualities (major/minor plus
   "no chord" first). Smooth candidates over time; preserve genuine changes.
4. Estimate an onset-strength envelope, tempo and beat positions. Classify
   *possible* attack events relative to the beat grid, without assigning
   stroke direction.
5. Store time-stamped segments/events with confidence and user edits separately
   from the raw model output. Render playback-synchronized, editable timeline.

This is an experiment design, not a commitment to any specific model. Build a
desktop research baseline first; only then decide whether Swift/Accelerate or
an on-device Core ML model is warranted. Do not add third-party runtime code or
model weights to the iOS app before checking their licenses and device cost.

## How to validate before building UI

Use GuitarSet's microphone mixes and aligned chord/beat annotations for a
reproducible first benchmark. Hold out players/performances, not random frames,
so adjacent audio cannot leak across train and test. Add a small consented set
of real phone recordings and a distinct full-band set, annotated by a musician.
The latter is the relevant test for the original "song recording" request.

Report separately for solo guitar and full mixes:

- Time-weighted chord correctness, chord-change timing and "no chord" errors.
- Beat-position tolerance, half/double-tempo mistakes and BPM stability.
- Attack-event precision/recall, including percussion-triggered false positives.
- End-to-end processing time, memory and battery on a supported iPhone.
- Cases the system explicitly declines to answer.

Establish acceptance thresholds with the musician after listening to examples;
do not derive a product promise from a single dataset score. Review the actual
confusion cases before choosing a model. A useful comparison is a simple
chroma/template + temporal-smoothing baseline against a learned model, evaluated
on the same held-out recordings.

## Main risks and product decisions

- A full song mix can hide guitar harmony behind bass, vocals, drums and other
  harmonic instruments. Isolated-guitar results will overstate product quality.
- Chord vocabulary is ambiguous: extensions, inversions, alternate tunings,
  capo and arpeggios need explicit "unknown" or simplified labels.
- BPM may be estimated at half/double the perceived pulse. Beat locations and
  strumming attacks are not interchangeable.
- Automatically inferred down/up strokes from a full mix are not a safe MVP
  claim. Research on joint chord/strum transcription exists, but its own
  recordings are guitar-focused, not evidence of arbitrary-song reliability.
- Imported copyrighted music must remain local; do not distribute test clips,
  bundled song recordings or user audio. Dataset and pretrained-weight licenses
  need review before any shipping use.

## Next decision

First run an offline, reproducible benchmark on GuitarSet and a tiny musician-
labeled phone-recording set. If chords and beat grid prove useful, implement the
editable import flow. Treat up/down strumming as a follow-up research track,
not a prerequisite for the chord chart.

## Primary sources

- [GuitarSet dataset and annotations](https://zenodo.org/records/3371780)
- [Beat tracking algorithm and implementation reference](https://librosa.org/doc/0.10.2/generated/librosa.beat.beat_track.html)
- [Joint chord and strumming-direction transcription research](https://github.com/Klangio/guitar-strumming-transcription)
- [Apple SwiftUI file importer](https://developer.apple.com/documentation/swiftui/view/fileimporter(isPresented:allowedContentTypes:allowsMultipleSelection:onCompletion:))
