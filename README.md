# ViewShare

crowdsourcing object location in cluttered environments

## Contents

* [Overview](#Overview)
* [Setup and dependencies](#setup-and-dependencies)
* [Architecture](#architecture)
* [Current status](#current-status)
* [Troubleshooting and Resources](#troubleshooting-and-resources)


## Overview

ViewShare uses crowdsourcing to enable a user to find objects in cluttered environments. A user who is blind can open ViewShare and request to find an object. Doing this sends a notification to a crowdworker, who can then click on the object in a series of pictures. The app then uses ARKit to localize the objects in 3D for the original requester with haptic feedback.

Part of the goal of ViewShare is to serve as an example framework of a crowdworker app, which we believe to be a useful tool for future researchers at our lab. More information coming soon!

ViewShare is being developed by [OCCaM Lab](http://occam.olin.edu/) at the [Olin College of Engineering](http://olin.edu/). Currently, we are developing a [web app crowdworker interface](https://github.com/occamLab/ViewShareCrowdWorker/tree/Webapp/Webapp) and updating documentation for the iOS app.

## Setup and dependencies

### iOS app

To use on your computer, clone this repository and open it by `cd`ing into your `ViewShareCrowdWorker` repository and typing `open View\ Share.xcworkspace`. (You should always open the workspace so it works well with CocoaPods).


#### System Requirements

ViewShare is written in Swift 4 and Xcode 9  and should work iOS devices with an A9 or later processor.

#### CocoaPods

[CocoaPods](https://cocoapods.org/) is a package manager for Swift projects.

To install, run:

```bash
sudo gem install cocoapods
```

To install the dependencies for this project and then open it:

```bash
cd ViewShareCrowdWorker
open View\ Share.xcworkspace
```

To add a new Pod to the project, add it to your Podfile. You can go to [cocoapods.org](cocoapods.org), search for your pod, and find TODO ADD MORE HERE. Once you've modified your Podfile, run:

```bash
pod install
```

This should add that dependency to the project.

For more information, check out the [CocoaPods Guides](guides.cocoapods.org)!

#### Firebase

If you're part of OccamLab, talk to someone about getting access to the Firebase console.

Otherwise, make a new project on the Firebase console. You will need to add the bundle ID that can be found in the `Info.plist` file.

Download `GoogleService-Info.plist` and put it in the `ViewShareCrowdWorker` directory.

#### Jazzy

[Jazzy](https://github.com/realm/jazzy "Jazzy") generates pretty documentation for Swift projects. See our documentation [here](occamlab.github.io/viewshare)!

To install, run:

```bash
sudo gem install jazzy
```

To update the documentation, run:

```bash
jazzy --min-acl internal
```

### Web app

Coming soon!

## How to run

### iOS app

From the `ViewShareCrowdWorker` directory in Terminal, run this command:

```bash
open .xcworkspace
```

Press the play/build triangle in the left corner of the Xcode toolbar.

If you have a developer signing error (which you may only see when trying to build it to a real device, instead of a simulator),

### Web app

Coming soon!

## Architecture

ViewShare is written in a model-view-controller framework. Much of the model is contained in the Firebase database. In the iOS app, the views and controllers are defined in the ViewController files.
#TODO: what makes sense


#TODO:
- [ ] describe iOS architecture somehow??? (this should probably be more bullet points)
- [ ] where does webapp fit in?
- [ ] what's up with Firebase?
- [ ] add link to docs

### iOS App

NOTE: this is very preliminary! Expect more complete, clear, and concise architecture descriptions coming soon.

For more complete documentation of the iOS code, check out the docs.

There are three ViewControllers in ViewShare iOS, each of which is primarily responsible for one of the scenes (found in the storyboard) and which interact with each other and Firebase.

#### `CollectionViewController.swift`

This view controller corresponds to the Assignments Scene, which contains thumbnail UIImages corresponding to assignments for the crowdworker.

`CollectionViewController` interacts with Firebase to sign in the user, as well as collect jobs from the database.

#### `ZoomedPhotoViewController.swift`

#### `PreviewCollectionViewController.swift`

### Web app

### Firebase database structure

## Current status

Right now, the active branches are [`add-documentation`](https://github.com/occamLab/ViewShareCrowdWorker/tree/add-documentation) and [`Webapp`](https://github.com/occamLab/ViewShareCrowdWorker/tree/Webapp). `add-documentation` is focused on getting the project as it was before (an iOS app and Firebase integration) documented, which means a comprehensive README, inline comments, and published generated documentation up. `Webapp` is focused on setting up a web-based version with the capacity of the crowdworker side of the iOS app, also integrated with Firebase.

More detail on what exactly works and next steps coming soon!

## Troubleshooting and resources

### Using a Mac

Look [here](http://osxdaily.com/2014/02/06/add-user-sudoers-file-mac/ "How to Add a User to the Sudoers File in Mac OS X") for instructions to resolve this error:
```
username is not in the sudoers file. This incident will be reported.
```

### Jazzy

If running Jazzy errors on

```
Could not parse compiler arguments from `xcodebuild` output
```

and the ``` `xcodebuild` ``` log file reads

```
xcode-select: error: toll 'xcodebuild' requires Xcode, but active developer directory '/Library/Developer/CommandLineTools' is a command line tools instance
```

try

```
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
```

[Source](https://github.com/realm/jazzy/issues/781 "Jazzy issues page")
