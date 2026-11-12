# LayerX

An intuitive app to display transparent images on screen.

[![Demo](http://img.youtube.com/vi/35KixjZBDjY/0.jpg)](http://www.youtube.com/watch?v=35KixjZBDjY)

# System requirements

Support Mac OS X 10.10 or later.

# Features

- [x] Drag and drop images
- [x] Keyboard Shortcuts
- [x] Adjust transparency  
- [x] Lock images
- [X] Aspect ratio scaling
- [x] Full-screen background with configurable color and opacity
- [x] Hold-to-show global shortcut

# Keyboard Shortcuts

### Set image

| Key | Action |
|:--- |:---    |
|`⌘ V`| Paste image or file from clipboard. |

### Scale

| Key | Action |
|:---|:---|
|`⌘ 0`| Actual image size.|
|`⌘ +`| Scale up 10%.|
|`⌘ -`| Scale down 10%.|
|`^ ⌘ +`| Scale up 1px.|
|`^ ⌘ -`| Scale down 1px.|

### Move (Arrow keys)

| Key | Action |
|:---|:---|
|`↑`| Move up 1px.|
|`←`| Move left 1px.|
|`→`| Move right 1px.|
|`↓`| Move down 1px.|

### Alpha

|Key|Action|
|:---|:---|
|`⌘ J`| Increase transparency.|
|`⌘ K`| Reduce transparency.|

### Window

|Key|Action|
|:---|:---|
|`⌘ L`| Lock images and make window always on top.|
|`⌘ T`| Make window always on top.|
|`⌘ A`| Keep window on all spaces.|

|`⌘ B`| Toggle the full-screen background.|

### Preferences (`⌘ ,`)

| Setting | Effect |
|:---|:---|
| Background | Covers the whole screen the image is on, behind the image. Clicks pass through it. |
| Color / Opacity | Color and transparency of that background. |
| Hold shortcut | A system-wide key combination. The overlay is shown for as long as it is held and hidden when it is released, without taking focus from the app in use. Either a key with at least one modifier, a function key, or modifiers alone (press and release just the modifiers while recording). Modifiers alone must be held for 0.2 s with no other key or click, so ordinary shortcuts do not trigger it; this is the option that works with tap-hold / home-row-mod keyboards. |

After the shortcut has hidden the overlay, click the Dock icon or choose **Window ▸ Show Overlay** to bring it back for editing.

# Mouse events

| Event | Action |
|:---|:---|
| Scroll up on image | Reduce transparency. |
| Scroll down on image | Increase transparency. |

# Building

Open `LayerX.xcodeproj` in Xcode, or from a terminal:

```sh
xcodebuild -project LayerX.xcodeproj -target LayerX -configuration Release SYMROOT="$PWD/build" build
```

Every push is built by GitHub Actions; the unsigned `LayerX.app` is attached to the workflow run as an artifact.

### Releasing

A build of `master` is published as a GitHub release, with `LayerX-vX.Y.Z.zip` attached, in either of two ways:

- On GitHub: **Actions ▸ Build ▸ Run workflow**, on `master`, with a version such as `1.3.0`.
- From a terminal: `git tag v1.3.0 && git push origin v1.3.0` on a commit that is on `master`.

The version is stamped into the app. Tags that are not on `master` are refused.

# Contact

Any suggestions are welcome. Find me at [@yuhua_twit](https://twitter.com/yuhua_twit)

# License

Copyright (c) 2017 Michael Chen (a.k.a. Yuhua Chen)

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
