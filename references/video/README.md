# Video files

The owner uploaded `videoplayback-part-one.mp4` (10 min 19 s, 640x360, about 31 MB): a playthrough of **ANALOG — Part 1, "The Sentient Robot"**.

It is deliberately **not committed to git**: it is a full copy of someone else's YouTube video, and it would add 31 MB to the repository's history for good. `.gitignore` excludes video files in this folder.

To have it here on your machine, copy the file into this folder. If you are an AI session on the owner's computer, ask them for it — they have the original — or work from `../analog-part1/`, which has 24 labelled stills, a frame every five seconds of the whole video, and written notes.

To pull more frames from a video (any timestamp, full size):

```bash
ffmpeg -ss 187 -i references/video/videoplayback-part-one.mp4 -frames:v 1 frame.jpg
```
