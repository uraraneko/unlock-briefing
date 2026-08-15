.PHONY: test build open

test:
	swift test --parallel

build:
	xcodebuild -project UnlockBriefing.xcodeproj -scheme UnlockBriefing -configuration Debug -destination 'platform=macOS' -derivedDataPath build/DerivedData CODE_SIGN_IDENTITY=- CODE_SIGNING_ALLOWED=YES AD_HOC_CODE_SIGNING_ALLOWED=YES ENABLE_DEBUG_DYLIB=NO
	ditto build/DerivedData/Build/Products/Debug/UnlockBriefing.app build/UnlockBriefing.app

open: build
	open build/UnlockBriefing.app
