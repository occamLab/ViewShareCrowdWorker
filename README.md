# ViewShare

crowdsourcing object location in cluttered environments

## Contents

- [Overview](#Overview)
- [Setup and dependencies](#setup-and-dependencies)
  - [iOS app](#ios-app)
  - [Web app](#web-app)
- [How to run](#how-to-run)
  - [iOS app](#run-the-ios-app)
  - [Web app](#run-the-web-app)
- [Architecture](#architecture)
  - [iOS app](#ios-app-architecture)
  - [Web app](#web-app-architecture)
  - [Firebase](#firebase-database-structure)
- [Current status](#current-status)
- [Troubleshooting and Resources](#troubleshooting-and-resources)

## Overview

ViewShare uses crowdsourcing to enable a user to find objects in cluttered environments. A user who is blind can open ViewShare and request to find an object. Doing this sends a notification to a crowdworker, who can then click on the object in a series of pictures. The app then uses ARKit to localize the objects in 3D for the original requester with haptic feedback.

Part of the goal of ViewShare is to serve as an example framework of a crowdworker app, which we believe to be a useful tool for future researchers at our lab. More information coming soon!

ViewShare is being developed by [OCCaM Lab](http://occam.olin.edu/) at the [Olin College of Engineering](http://olin.edu/). Currently, we are developing a [web app crowdworker interface](https://github.com/occamLab/ViewShareCrowdWorker/tree/Webapp/Webapp) and updating documentation for the iOS app.

## Setup and dependencies

### iOS app

To use on your computer, clone this repository and open it by `cd`ing into your `ViewShareCrowdWorker` repository and typing `open View\ Share.xcworkspace`. (You should always open the workspace so it works well with CocoaPods).

#### System Requirements

ViewShare is written in Swift 4 and Xcode 9 and should work iOS devices with an A9 or later processor.

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

If you're part of OccamLab, talk to someone about getting access to the Firebase console. Once you have access to the console, click the gear at the top of the menu on the left side on the screen and then choose Project settings from the options provided. Finally, scroll down to "Your Apps" and download `GoogleService-Info.plist`.

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

### Run the iOS app

From the `ViewShareCrowdWorker` directory in Terminal, run this command:

```bash
open .xcworkspace
```

Press the play/build triangle in the left corner of the Xcode toolbar.

If you have a developer signing error (which you may only see when trying to build it to a real device, instead of a simulator), check your signing certificate.

### Run the web app

To run on a local server: run `firebase sentToServer` from the directory containing the firebase project

## Architecture

### iOS App Architecture

For more details about the iOS code, check out the [docs](occamlab.github.io/viewsharecrowdworker).

There are three scenes in this project: Assignments (Collection View Controller), Zoomed Photo View Controller, and Preview Collection View Controller.

`CollectionViewController` handles both the login UI (with Firebase Auth) and the collection of assignments. When an assignment is opened, its data is passed to `ZoomedPhotoViewController`, and the app segues to the `ZoomedPhotoViewController` and `PreviewCollectionViewController` scenes.

The `ZoomedPhotoViewController` scene takes up the majority of the screen and allows the crowdworker to zoom in the photo and select the location of an object. It also handles listening for new photos from and sending locations clicked on images to the Firebase database, which is how the crowdworker and requesting user sides of ViewShare interact.

The `PreviewCollectionViewController` scene is a collection of images associated with the currently open assignment. `ZoomedPhotoViewController` and `PreviewCollectionViewController` communicate about switching between images in a job using a Notification Center.

### Web app architecture

`index.html` is the landing page for a user that is not signed in, and gives the option to either log in or register a new account. Once the user logs in, the page redirects to `interface.html`, which is the page where a user can answer assignments given to them.
`logintest.html` is a page that was used for testing that the login sequence was functional, but is no longer directly in use

`config.js` has the necessary initialization for the app to work and connect to firebase
`notifications.js` holds the script that allows for users to be notified when a new job is assigned to them
`uuidGenerator.js` contains a function that is used to generate a UUID, using code from npm package [`uuid`](https://www.npmjs.com/package/uuid)

`database.rules.json` defines the set of rules for accessing the database
`firebase.json` sets the site up so it can be served through firebase
`manifest.json` is a setup that defines some of the metadata of the page


### Firebase database structure

Firebase provides NoSQL databases. Our ViewShare database schema is available in our Documentation folder on the Google Drive for OccamLab members or by request. We use Firebase to store Firebase cloud messaging tokens, user IDs, job IDs, assignments, notifications, image IDs, and responses, as well as storing images with Firebase Storage.

## Current status

Right now, the active branches are [`add-documentation`](https://github.com/occamLab/ViewShareCrowdWorker/tree/add-documentation) and [`Webapp`](https://github.com/occamLab/ViewShareCrowdWorker/tree/Webapp).

`add-documentation` is focused on getting the project as it was before (an iOS app and Firebase integration) documented, which means a comprehensive README, inline comments, and published generated documentation up.

`Webapp` is focused on setting up a web-based version with the capacity of the crowdworker side of the iOS app, also integrated with Firebase.

Our potential next steps include:

- more user testing!
- research on crowdworking
- some code cleanup
- documentation on the requesting user side of the project
- deployment to TestFlight

## Troubleshooting and resources

### Using a Mac

Look [here](http://osxdaily.com/2014/02/06/add-user-sudoers-file-mac/ "How to Add a User to the Sudoers File in Mac OS X") for instructions to resolve this error:

```
username is not in the sudoers file. This incident will be reported.
```

### Jazzy

If running Jazzy errors with this message:

```
Could not parse compiler arguments from `xcodebuild` output
```

and the `` `xcodebuild` `` log file contains this:

```
xcode-select: error: toll 'xcodebuild' requires Xcode, but active developer directory '/Library/Developer/CommandLineTools' is a command line tools instance
```

try running:

```
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
```

[Source](https://github.com/realm/jazzy/issues/781 "Jazzy issues page")
