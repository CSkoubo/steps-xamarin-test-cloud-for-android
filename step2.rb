
#Build test
"/Applications/Xamarin Studio.app/Contents/MacOS/mdtool" build "-c:TestCloud" "MyPackSmall.sln" "-p:MyPackSmall.Spec"

#Build Android
xbuild /t:PackageForAndroid /p:Configuration="TestCloud" "./Droid/MyPackSmall.Droid.csproj" /verbosity:minimal /nologo
jarsigner -sigalg SHA1withDSA -digestalg SHA1 -keypass $BITRISEIO_ANDROID_KEYSTORE_PRIVATE_KEY_PASSWORD -storepass $BITRISEIO_ANDROID_KEYSTORE_PASSWORD -keystore release_temp.keystore ./Droid/bin/TestCloud/com.postnord.mypacksmall.apk $BITRISEIO_ANDROID_KEYSTORE_ALIAS

#Build iOS
"/Applications/Xamarin Studio.app/Contents/MacOS/mdtool" build "-c:TestCloud|iPhone" "MyPackSmall.sln" "-p:MyPackSmall.iOS"
"/Applications/Xamarin Studio.app/Contents/MacOS/mdtool" archive "-c:TestCloud|iPhone" "MyPackSmall.sln" "-p:MyPackSmall.iOS"

/Users/vagrant/Library/Developer/Xamarin/android-sdk-macosx/build-tools/19.1.0/zipalign -f 4 ./Droid/bin/TestCloud/com.postnord.mypacksmall.apk ./Droid/bin/TestCloud/com.postnord.mypacksmall-signed.apk

cat >export_options.plist <<EOL
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>method</key>
  <string>development</string>
</dict>
</plist>
EOL

xcodebuild -exportArchive -archivePath "$(ls -d $HOME/Library/Developer/Xcode/Archives/**/*.xcarchive | tail -n 1)" -exportPath . -exportOptionsPlist "export_options.plist"


#Submit to testcloud
mono "packages/Xamarin.UITest.2.0.0-beta02/tools/test-cloud.exe" submit "$(ls *.ipa | tail -n 1)" 72bba1cec2134373d8e84f75a24a9244 --user jonas@jonasl.dk --assembly-dir "./MyPackSmall.Spec/bin/TestCloud" --devices 2b725d13 --async-json --series master | tee xtc_android_upload.log
mono "packages/Xamarin.UITest.2.0.0-beta02/tools/test-cloud.exe" submit ./Droid/bin/TestCloud/com.postnord.mypacksmall-signed.apk 72bba1cec2134373d8e84f75a24a9244 --user jonas@jonasl.dk --assembly-dir "./MyPackSmall.Spec/bin/TestCloud" --devices d0b03af1 --async-json --series master --test-params screencapture:true | tee xtc_ios_upload.log


envman add --key BITRISE_XAMARIN_ANDROID_TEST_ID --value $(grep -oP '"TestRunId":"\K([^"]*)' xtc_android_upload.log)
envman add --key BITRISE_XAMARIN_ANDROID_TEST_RUL_URL --value "https://testcloud.xamarin.com/test/$BITRISE_XAMARIN_ANDROID_TEST_ID"

envman add --key BITRISE_XAMARIN_IOS_TEST_ID --value $(grep -oP '"TestRunId":"\K([^"]*)' xtc_ios_upload.log)
envman add --key BITRISE_XAMARIN_ANDROID_TEST_RUL_URL --value "https://testcloud.xamarin.com/test/$BITRISE_XAMARIN_IOS_TEST_ID"
