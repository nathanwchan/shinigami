# Tweetsee app for iOS ![Tweetsee icon](https://github.com/nathanwchan/shinigami/blob/master/shinigami/icons/AppIcon-40x40%401x.png)

### Overview
See Twitter through someone else's eyes.

### Main technologies
* Swift 3
* UIKit
* [CocoaPods](https://cocoapods.org/)
* [Twitter Kit for iOS](https://dev.twitter.com/twitterkit/ios/overview)
* [Realm Swift](https://realm.io/docs/swift/latest/)
* [SwiftyJSON](https://github.com/SwiftyJSON/SwiftyJSON)
* [Firebase Analytics](https://firebase.google.com/docs/analytics/)
* [SwiftLint](https://github.com/realm/SwiftLint)
* [PromiseKit](https://github.com/mxcl/PromiseKit)

### Contributing
You are welcome to work on any bug or feature you would like. We recommend that you take a look at issues labeled as [Your First PR](https://github.com/nathanwchan/shinigami/issues?q=is%3Aissue+is%3Aopen+label%3A%22Your+First+PR%22). These issues are relatively small and self-contained, and should be perfect for anyone who is interested in getting their feet wet with the codebase.

### Installation
* CocoaPods:
  * [Install CocoaPods](https://guides.cocoapods.org/using/getting-started.html)
  * Run `pod install`
* TwitterKit:
  * Create your own [Twitter app](https://apps.twitter.com)
  * Follow steps [here](https://dev.twitter.com/twitterkit/ios/installation#configure-info-plist) to configure your Info.plist file
  * Create a Keys.plist file in the root directory with the following key-values:
    * "TwitterConsumerKey": <Consumer Key (API Key) from your Twitter app>
    * "TwitterConsumerSecret": <Consumer Secret (API Secret) from your Twitter app>
* Firebase Analytics:
  * Follow steps [here](https://firebase.google.com/docs/ios/setup) to download a `GoogleService-Info.plist` file and copy it into the Xcode project
