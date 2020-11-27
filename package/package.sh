#!/bin/sh
export LANG=zh_CN.UTF-8 

buildConfig=Debug
projectName="ProjectName" # 需修改
workSpacePath="./${projectName}.xcworkspace"
buildFolder="./build"
plistFolder="./${projectName}/SupportingFiles" # 路径看自己工程去配置

exportPlistDevelopment="package/ExportOptionsDevelopment.plist" # plist需修改
exportPlistAdhoc="package/ExportOptionsAdhoc.plist" # plist需修改
exportPlistRelease="package/ExportOptionsRelease.plist" # plist需修改
exportOptionsPlist=""

infoDevPlist="${plistFolder}/Info-dev.plist"
infoPlist="${plistFolder}/Info.plist"

archivePath="${buildFolder}/${projectName}.xcarchive"
ipaFolderPath="${buildFolder}/${projectName}"
# appName=`/usr/libexec/PlistBuddy -c "Print CFBundleDisplayName" ${infoPlistPath}`
appName="app名称"
firApiToken="firApiToken" #上传fir用
firLog=""
uploadToAppStoreFlag=0

bundleVersionDev=`/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" $infoDevPlist`
bundleVersion=`/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" $infoPlist`
bundleIdentifier=`/usr/libexec/PlistBuddy -c "Print CFBundleIdentifier" $infoPlist`
bundleBuildVersionDev=`/usr/libexec/PlistBuddy -c "Print CFBundleVersion" $infoDevPlist`
bundleBuildVersion=`/usr/libexec/PlistBuddy -c "Print CFBundleVersion" $infoPlist`

PLPlayerKitSimulator="pod 'PLPlayerKit', :podspec => 'http:\/\/raw.githubusercontent.com\/pili-engineering\/PLPlayerKit\/master\/PLPlayerKit-Universal.podspec'"
PLPlayerKitDevice="pod 'PLPlayerKit'"

modifyPodfileForAppStore() { #以七牛播放器为例子
    echo "******>修改podfile，移除x86 i386"
    if [ `grep -c "${PLPlayerKitSimulator}" "Podfile"` -ne '0' ]; then
        sed -i "" "s/${PLPlayerKitSimulator}/${PLPlayerKitDevice}/g" Podfile
    fi
    echo "******>pod install"
    pod install
}
recoverPodfileForAllArchs() {
    echo "******>恢复podFile"
    if [ `grep -c "${PLPlayerKitSimulator}" "Podfile"` -ne '0' ]; then
        echo "******>PLPlayerKit包含模拟器"
    else
        sed -i "" "s/${PLPlayerKitDevice}/${PLPlayerKitSimulator}/g" Podfile
    fi
    echo "******>pod install"
    pod install
}

echo "******>请选择导出方法 ? [ 1:dev 2.ad-hoc 3:release ] "
read method
while [[ $method != 1 ]] && [[ $method != 2 ]] && [[ $method != 3 ]]; do
    echo "******>请选择导出方法 ? [ 1:dev 2.ad-hoc 3:release ] "
    read method
done

echo "******>请输入更新日志? "
read updateLog
echo "******>更新日志$updateLog"

echo "******>移除build"
rm -rf $buildFolder

# 默认打包demo
if [[ "$method" == 1 ]]; then
    buildConfig=Debug
    exportOptionsPlist=${exportPlistDevelopment}
    firLog="$updateLog Debug "
    recoverPodfileForAllArchs
elif [[ "$method" == 2 ]]; then
    buildConfig=Release
    exportOptionsPlist=${exportPlistAdhoc}
    firLog="$updateLog Release adhoc "
    recoverPodfileForAllArchs
elif [[ "$method" == 3 ]]; then
    buildConfig=Release
    exportOptionsPlist=${exportPlistRelease}
    firLog="$updateLog Release appStore"
    echo "if upload ipa to AppStore ? [1: YES 2: NO]"
    read flag
    if [[ "$flag" == 1 ]]; then
        uploadToAppStoreFlag=$flag
    else
        uploadToAppStoreFlag=0
    fi
    modifyPodfileForAppStore
else
    buildConfig=Debug
    exportOptionsPlist=${exportPlistDevelopment}
    recoverPodfileForAllArchs
fi

echo "******>clean..."
xcodebuild clean -workspace $workSpacePath -scheme $projectName -configuration $buildConfig -quiet || exit

echo "******>archive..."
xcodebuild archive -workspace $workSpacePath -scheme $projectName -configuration $buildConfig -archivePath $archivePath  || exit

echo "******>导出ipa中..."
xcodebuild -exportArchive -archivePath $archivePath -exportPath ${ipaFolderPath} -exportOptionsPlist ${exportOptionsPlist} -quiet || exit

if [[ -e ${ipaFolderPath}/${appName}.ipa ]]; then
    echo "******>ipa 导出成功"
    ipaFilePath="${ipaFolderPath}/${appName}.ipa"
    if [[ "${method}" == 3 ]]; then
        if [[ ${uploadToAppStoreFlag} == 1 ]]; then
            # build config is release and method is app-store， then upload ipa to app store
            echo "******>请输入开发者账号："
            read developAppleID
            sleep 0.2
            echo "******>请输入开发者账号专用密码：(专业密码需要到https://appleid.apple.com/account/manage生成)"
            stty -echo
            read developPassword
            stty echo
            sleep 0.2
            altoolPath="/Applications/Xcode.app/Contents/SharedFrameworks/ContentDeliveryServices.framework/Versions/A/Frameworks/AppStoreService.framework/Versions/A/Support/altool"
            #appleid和专用密码上传
            xcrun altool --validate-app -f "${ipaFilePath}" -t iOS -u "${developAppleID}"  -p "${developPassword}" --verbose --output-format xml || exit  
            xcrun altool --upload-app -f "${ipaFilePath}" -t iOS -u "${developAppleID}"  -p "${developPassword}" --verbose --output-format xml || exit
            #使用密钥上传(需要持有人在itunesConnect生成)
            # apiKey=""
            # apiIssuer=""
            # xcrun altool --validate-app -f "${ipaFilePath}" -t iOS --apiKey $apiKey --apiIssuer $apiIssuer --verbose --output-format xml || exit
            # xcrun altool --upload-app -f "${ipaFilePath}" -t iOS --apiKey $apiKey --apiIssuer $apiIssuer --verbose --output-format xml || exit
            echo "******>上传app store成功"
        else
            echo "******>不需要上传到app store，执行完毕"
        fi
    else 
        echo "******>正在上传到fir.im...."
        echo "******>ipa路径 ${ipaFilePath}....log : ${firLog}"
        fir p $ipaFilePath -c ${firLog} -T ${firApiToken} -V -R || exit
        echo "******>上传成功！"
    fi
else
    echo "******>没有导出ipa"
fi

