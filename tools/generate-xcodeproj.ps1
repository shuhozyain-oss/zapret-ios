<#
.SYNOPSIS
    Generates <Project>.xcodeproj (iOS app target) from the Swift sources in Sources/.

.DESCRIPTION
    XcodeGen / swift package generate-xcodeproj are unavailable on Windows, so this script
    writes project.pbxproj + a shared scheme directly. Re-run it after adding or renaming
    source files or asset catalogs.

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File tools\generate-xcodeproj.ps1
#>
[CmdletBinding()]
param(
    [string]$ProjectName = "zapret",
    [string]$BundleId = "com.example.zapret",
    [string]$DeploymentTarget = "17.0",
    [string]$Scheme = "zapret"
)

$ErrorActionPreference = "Stop"
$q = [char]34

$rootDir = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..")).Path
$projectDir = Join-Path $rootDir "$ProjectName.xcodeproj"
$schemeDir = Join-Path $projectDir "xcshareddata/xcschemes"

$script:objectCounter = 0
function New-ObjectId {
    $script:objectCounter = $script:objectCounter + 1
    return ("AA{0:X22}" -f $script:objectCounter)
}

function Get-RelativePath([string]$fullPath) {
    $relative = $fullPath.Substring($rootDir.Length).TrimStart([char[]]@('\', '/'))
    return ($relative -replace '\\', '/')
}

function Get-ParentPath([string]$relativePath) {
    $index = $relativePath.LastIndexOf('/')
    if ($index -lt 0) { return "" }
    return $relativePath.Substring(0, $index)
}

$srcDir = Join-Path $rootDir "Sources"
if (-not (Test-Path -LiteralPath $srcDir)) { throw "Sources directory not found: $srcDir" }

$swiftFiles = @(Get-ChildItem -LiteralPath $srcDir -Recurse -File -Filter *.swift | Sort-Object FullName)
if ($swiftFiles.Count -eq 0) { throw "No Swift files found under $srcDir" }

$assetCatalogs = @(Get-ChildItem -LiteralPath $srcDir -Recurse -Directory | Where-Object { $_.Extension -eq ".xcassets" })

# ---------------------------------------------------------------- file entries
$entries = New-Object System.Collections.ArrayList
foreach ($file in $swiftFiles) {
    [void]$entries.Add([pscustomobject]@{
        RelativePath = Get-RelativePath $file.FullName
        FileType     = "sourcecode.swift"
        BuildPhase   = "Sources"
    })
}
foreach ($catalog in $assetCatalogs) {
    [void]$entries.Add([pscustomobject]@{
        RelativePath = Get-RelativePath $catalog.FullName
        FileType     = "folder.assetcatalog"
        BuildPhase   = "Resources"
    })
}

$plistPath = "Info.plist"
if (Test-Path -LiteralPath (Join-Path $rootDir $plistPath)) {
    [void]$entries.Add([pscustomobject]@{
        RelativePath = $plistPath
        FileType     = "text.plist.xml"
        BuildPhase   = ""
    })
}

# ---------------------------------------------------------------- directories
$directorySet = New-Object 'System.Collections.Generic.HashSet[string]'
foreach ($entry in $entries) {
    [void]$directorySet.Add((Get-ParentPath $entry.RelativePath))
}

$allDirectories = @($directorySet)
foreach ($directory in $allDirectories) {
    $parts = $directory.Split('/')
    for ($i = 1; $i -le $parts.Length; $i++) {
        [void]$directorySet.Add((($parts[0..($i - 1)]) -join '/'))
    }
}

# ---------------------------------------------------------------- object ids
$fileRefIds = @{}
$buildFileIds = @{}
foreach ($entry in $entries) {
    $fileRefIds[$entry.RelativePath] = New-ObjectId
}
foreach ($entry in $entries) {
    if ($entry.BuildPhase -ne "") {
        $buildFileIds[$entry.RelativePath] = New-ObjectId
    }
}

$groupIds = @{}
foreach ($directory in @($directorySet | Sort-Object)) {
    $groupIds[$directory] = New-ObjectId
}

$mainGroupId = New-ObjectId
$productsGroupId = New-ObjectId
$targetId = New-ObjectId
$productReferenceId = New-ObjectId
$sourcesPhaseId = New-ObjectId
$frameworksPhaseId = New-ObjectId
$resourcesPhaseId = New-ObjectId
$projectConfigListId = New-ObjectId
$targetConfigListId = New-ObjectId
$projectDebugId = New-ObjectId
$projectReleaseId = New-ObjectId
$targetDebugId = New-ObjectId
$targetReleaseId = New-ObjectId
$projectId = New-ObjectId

# ---------------------------------------------------------------- groups
$childrenByDirectory = @{}
foreach ($directory in $directorySet) {
    $childrenByDirectory[$directory] = New-Object System.Collections.ArrayList
}

foreach ($entry in $entries) {
    $parent = Get-ParentPath $entry.RelativePath
    if ($parent -eq "" -and $entry.BuildPhase -eq "") {
        [void]$childrenByDirectory[""].Add("FILE:$($entry.RelativePath)")
        continue
    }
    if ($childrenByDirectory.ContainsKey($parent)) {
        [void]$childrenByDirectory[$parent].Add("FILE:$($entry.RelativePath)")
    }
}

foreach ($directory in $directorySet) {
    if ($directory -eq "") { continue }
    $parent = Get-ParentPath $directory
    if ($childrenByDirectory.ContainsKey($parent)) {
        [void]$childrenByDirectory[$parent].Add("GROUP:$directory")
    }
}

function Get-GroupName([string]$directory) {
    $index = $directory.LastIndexOf('/')
    if ($index -lt 0) { return $directory }
    return $directory.Substring($index + 1)
}

# ---------------------------------------------------------------- build settings
$commonSigning = @'
				CODE_SIGN_IDENTITY = "";
				CODE_SIGNING_ALLOWED = NO;
				CODE_SIGNING_REQUIRED = NO;
				CODE_SIGN_STYLE = Manual;
				DEVELOPMENT_TEAM = "";
				PROVISIONING_PROFILE_SPECIFIER = "";
'@

$commonSigning = "`n" + $commonSigning.Trim("`r", "`n")
$projectDebugSettings = @'
				ALWAYS_SEARCH_USER_PATHS = NO;
				CLANG_ENABLE_MODULES = YES;
				CLANG_ENABLE_OBJC_ARC = YES;
				COPY_PHASE_STRIP = NO;
				DEBUG_INFORMATION_FORMAT = dwarf;
				ENABLE_STRICT_OBJC_MSGSEND = YES;
				ENABLE_TESTABILITY = YES;
				GCC_C_LANGUAGE_STANDARD = gnu17;
				GCC_DYNAMIC_NO_PIC = NO;
				GCC_NO_COMMON_BLOCKS = YES;
				GCC_OPTIMIZATION_LEVEL = 0;
				GCC_PREPROCESSOR_DEFINITIONS = (
					"DEBUG=1",
					"$(inherited)",
				);
				IPHONEOS_DEPLOYMENT_TARGET = __DEPLOYMENT__;
				MTL_ENABLE_DEBUG_INFO = INCLUDE_SOURCE;
				MTL_FAST_MATH = YES;
				ONLY_ACTIVE_ARCH = YES;
				SDKROOT = iphoneos;
				SWIFT_ACTIVE_COMPILATION_CONDITIONS = "DEBUG $(inherited)";
				SWIFT_OPTIMIZATION_LEVEL = "-Onone";
'@

$projectReleaseSettings = @'
				ALWAYS_SEARCH_USER_PATHS = NO;
				CLANG_ENABLE_MODULES = YES;
				CLANG_ENABLE_OBJC_ARC = YES;
				COPY_PHASE_STRIP = NO;
				DEBUG_INFORMATION_FORMAT = "dwarf-with-dsym";
				ENABLE_NS_ASSERTIONS = NO;
				ENABLE_STRICT_OBJC_MSGSEND = YES;
				GCC_C_LANGUAGE_STANDARD = gnu17;
				GCC_NO_COMMON_BLOCKS = YES;
				IPHONEOS_DEPLOYMENT_TARGET = __DEPLOYMENT__;
				MTL_ENABLE_DEBUG_INFO = NO;
				MTL_FAST_MATH = YES;
				SDKROOT = iphoneos;
				SWIFT_COMPILATION_MODE = wholemodule;
				SWIFT_OPTIMIZATION_LEVEL = "-O";
				VALIDATE_PRODUCT = YES;
'@

$targetSettings = @'
				ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;
				ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME = AccentColor;
				CURRENT_PROJECT_VERSION = 1;
				ENABLE_USER_SCRIPT_SANDBOXING = NO;
				GENERATE_INFOPLIST_FILE = NO;
				INFOPLIST_FILE = Info.plist;
				IPHONEOS_DEPLOYMENT_TARGET = __DEPLOYMENT__;
				LD_RUNPATH_SEARCH_PATHS = (
					"$(inherited)",
					"@executable_path/Frameworks",
				);
				MARKETING_VERSION = 1.0;
				PRODUCT_BUNDLE_IDENTIFIER = __BUNDLE__;
				PRODUCT_NAME = "$(TARGET_NAME)";
				SWIFT_EMIT_LOC_STRINGS = NO;
				SWIFT_VERSION = 5.0;
				TARGETED_DEVICE_FAMILY = "1,2";
'@

$projectDebugSettings = $projectDebugSettings.Replace("__DEPLOYMENT__", $DeploymentTarget).TrimEnd("`r", "`n") + $commonSigning
$projectReleaseSettings = $projectReleaseSettings.Replace("__DEPLOYMENT__", $DeploymentTarget).TrimEnd("`r", "`n") + $commonSigning
$targetSettings = $targetSettings.Replace("__DEPLOYMENT__", $DeploymentTarget).Replace("__BUNDLE__", $BundleId).TrimEnd("`r", "`n") + $commonSigning

# ---------------------------------------------------------------- pbxproj
$sb = New-Object System.Text.StringBuilder

function Append-Line([string]$line) {
    [void]$sb.Append($line + "`n")
}

Append-Line "// !$*UTF8*$!"
Append-Line "{"
Append-Line "	archiveVersion = 1;"
Append-Line "	classes = {"
Append-Line "	};"
Append-Line "	objectVersion = 56;"
Append-Line "	objects = {"

# --- PBXBuildFile
Append-Line ""
Append-Line "/* Begin PBXBuildFile section */"
foreach ($entry in $entries) {
    if ($entry.BuildPhase -eq "") { continue }
    $fileName = Get-GroupName $entry.RelativePath
    Append-Line "		$($buildFileIds[$entry.RelativePath]) /* $fileName in $($entry.BuildPhase) */ = {isa = PBXBuildFile; fileRef = $($fileRefIds[$entry.RelativePath]) /* $fileName */; };"
}
Append-Line "/* End PBXBuildFile section */"

# --- PBXFileReference
Append-Line ""
Append-Line "/* Begin PBXFileReference section */"
foreach ($entry in $entries) {
    $fileName = Get-GroupName $entry.RelativePath
    Append-Line "		$($fileRefIds[$entry.RelativePath]) /* $fileName */ = {isa = PBXFileReference; lastKnownFileType = $($entry.FileType); path = $fileName; sourceTree = ""<group>""; };"
}
Append-Line "		$productReferenceId /* $ProjectName.app */ = {isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = $ProjectName.app; sourceTree = BUILT_PRODUCTS_DIR; };"
Append-Line "/* End PBXFileReference section */"

# --- PBXFrameworksBuildPhase
Append-Line ""
Append-Line "/* Begin PBXFrameworksBuildPhase section */"
Append-Line "		$frameworksPhaseId /* Frameworks */ = {"
Append-Line "			isa = PBXFrameworksBuildPhase;"
Append-Line "			buildActionMask = 2147483647;"
Append-Line "			files = ("
Append-Line "			);"
Append-Line "			runOnlyForDeploymentPostprocessing = 0;"
Append-Line "		};"
Append-Line "/* End PBXFrameworksBuildPhase section */"

# --- PBXGroup
Append-Line ""
Append-Line "/* Begin PBXGroup section */"
foreach ($directory in @($directorySet | Sort-Object)) {
    if ($directory -eq "") { continue }
    $name = Get-GroupName $directory
    Append-Line "		$($groupIds[$directory]) /* $name */ = {"
    Append-Line "			isa = PBXGroup;"
    Append-Line "			children = ("
    foreach ($child in $childrenByDirectory[$directory]) {
        if ($child.StartsWith("GROUP:")) {
            $childDirectory = $child.Substring(6)
            $childName = Get-GroupName $childDirectory
            Append-Line "				$($groupIds[$childDirectory]) /* $childName */,"
        } else {
            $childPath = $child.Substring(5)
            $childName = Get-GroupName $childPath
            Append-Line "				$($fileRefIds[$childPath]) /* $childName */,"
        }
    }
    Append-Line "			);"
    if ($directory -ne "") {
        Append-Line "			path = $name;"
    }
    Append-Line "			sourceTree = $q<group>$q;"
    Append-Line "		};"
}
Append-Line "		$mainGroupId /* $ProjectName */ = {"
Append-Line "			isa = PBXGroup;"
Append-Line "			children = ("
foreach ($child in $childrenByDirectory[""]) {
    if ($child.StartsWith("GROUP:")) {
        $childDirectory = $child.Substring(6)
        Append-Line "				$($groupIds[$childDirectory]) /* $(Get-GroupName $childDirectory) */,"
    } else {
        $childPath = $child.Substring(5)
        Append-Line "				$($fileRefIds[$childPath]) /* $(Get-GroupName $childPath) */,"
    }
}
Append-Line "				$productsGroupId /* Products */,"
Append-Line "			);"
Append-Line "			sourceTree = $q<group>$q;"
Append-Line "		};"
Append-Line "		$productsGroupId /* Products */ = {"
Append-Line "			isa = PBXGroup;"
Append-Line "			children = ("
Append-Line "				$productReferenceId /* $ProjectName.app */,"
Append-Line "			);"
Append-Line "			name = Products;"
Append-Line "			sourceTree = $q<group>$q;"
Append-Line "		};"
Append-Line "/* End PBXGroup section */"

# --- PBXNativeTarget
Append-Line ""
Append-Line "/* Begin PBXNativeTarget section */"
Append-Line "		$targetId /* $ProjectName */ = {"
Append-Line "			isa = PBXNativeTarget;"
Append-Line "			buildConfigurationList = $targetConfigListId /* Build configuration list for PBXNativeTarget ""$ProjectName"" */;"
Append-Line "			buildPhases = ("
Append-Line "				$sourcesPhaseId /* Sources */,"
Append-Line "				$frameworksPhaseId /* Frameworks */,"
Append-Line "				$resourcesPhaseId /* Resources */,"
Append-Line "			);"
Append-Line "			buildRules = ("
Append-Line "			);"
Append-Line "			dependencies = ("
Append-Line "			);"
Append-Line "			name = $ProjectName;"
Append-Line "			productName = $ProjectName;"
Append-Line "			productReference = $productReferenceId /* $ProjectName.app */;"
Append-Line ('			productType = ' + $q + 'com.apple.product-type.application' + $q + ';')
Append-Line "		};"
Append-Line "/* End PBXNativeTarget section */"

# --- PBXProject
Append-Line ""
Append-Line "/* Begin PBXProject section */"
Append-Line "		$projectId /* Project object */ = {"
Append-Line "			isa = PBXProject;"
Append-Line "			attributes = {"
Append-Line "				BuildIndependentTargetsInParallel = 1;"
Append-Line "				LastSwiftUpdateCheck = 1530;"
Append-Line "				LastUpgradeCheck = 1530;"
Append-Line "				TargetAttributes = {"
Append-Line "					$targetId = {"
Append-Line "						CreatedOnToolsVersion = 15.3;"
Append-Line "					};"
Append-Line "				};"
Append-Line "			};"
Append-Line "			buildConfigurationList = $projectConfigListId /* Build configuration list for PBXProject ""$ProjectName"" */;"
Append-Line ('			compatibilityVersion = ' + $q + 'Xcode 14.0' + $q + ';')
Append-Line "			developmentRegion = ru;"
Append-Line "			hasScannedForEncodings = 0;"
Append-Line "			knownRegions = ("
Append-Line "				ru,"
Append-Line "				en,"
Append-Line "				Base,"
Append-Line "			);"
Append-Line "			mainGroup = $mainGroupId;"
Append-Line "			productRefGroup = $productsGroupId /* Products */;"
Append-Line "			projectDirPath = $q$q;"
Append-Line "			projectRoot = $q$q;"
Append-Line "			targets = ("
Append-Line "				$targetId /* $ProjectName */,"
Append-Line "			);"
Append-Line "		};"
Append-Line "/* End PBXProject section */"

# --- PBXResourcesBuildPhase
Append-Line ""
Append-Line "/* Begin PBXResourcesBuildPhase section */"
Append-Line "		$resourcesPhaseId /* Resources */ = {"
Append-Line "			isa = PBXResourcesBuildPhase;"
Append-Line "			buildActionMask = 2147483647;"
Append-Line "			files = ("
foreach ($entry in $entries) {
    if ($entry.BuildPhase -ne "Resources") { continue }
    $fileName = Get-GroupName $entry.RelativePath
    Append-Line "				$($buildFileIds[$entry.RelativePath]) /* $fileName in Resources */,"
}
Append-Line "			);"
Append-Line "			runOnlyForDeploymentPostprocessing = 0;"
Append-Line "		};"
Append-Line "/* End PBXResourcesBuildPhase section */"

# --- PBXSourcesBuildPhase
Append-Line ""
Append-Line "/* Begin PBXSourcesBuildPhase section */"
Append-Line "		$sourcesPhaseId /* Sources */ = {"
Append-Line "			isa = PBXSourcesBuildPhase;"
Append-Line "			buildActionMask = 2147483647;"
Append-Line "			files = ("
foreach ($entry in $entries) {
    if ($entry.BuildPhase -ne "Sources") { continue }
    $fileName = Get-GroupName $entry.RelativePath
    Append-Line "				$($buildFileIds[$entry.RelativePath]) /* $fileName in Sources */,"
}
Append-Line "			);"
Append-Line "			runOnlyForDeploymentPostprocessing = 0;"
Append-Line "		};"
Append-Line "/* End PBXSourcesBuildPhase section */"

# --- XCBuildConfiguration
Append-Line ""
Append-Line "/* Begin XCBuildConfiguration section */"
Append-Line "		$projectDebugId /* Debug */ = {"
Append-Line "			isa = XCBuildConfiguration;"
Append-Line "			buildSettings = {"
Append-Line ($projectDebugSettings.TrimEnd("`r", "`n"))
Append-Line "			};"
Append-Line "			name = Debug;"
Append-Line "		};"
Append-Line "		$projectReleaseId /* Release */ = {"
Append-Line "			isa = XCBuildConfiguration;"
Append-Line "			buildSettings = {"
Append-Line ($projectReleaseSettings.TrimEnd("`r", "`n"))
Append-Line "			};"
Append-Line "			name = Release;"
Append-Line "		};"
Append-Line "		$targetDebugId /* Debug */ = {"
Append-Line "			isa = XCBuildConfiguration;"
Append-Line "			buildSettings = {"
Append-Line ($targetSettings.TrimEnd("`r", "`n"))
Append-Line "			};"
Append-Line "			name = Debug;"
Append-Line "		};"
Append-Line "		$targetReleaseId /* Release */ = {"
Append-Line "			isa = XCBuildConfiguration;"
Append-Line "			buildSettings = {"
Append-Line ($targetSettings.TrimEnd("`r", "`n"))
Append-Line "			};"
Append-Line "			name = Release;"
Append-Line "		};"
Append-Line "/* End XCBuildConfiguration section */"

# --- XCConfigurationList
Append-Line ""
Append-Line "/* Begin XCConfigurationList section */"
Append-Line "		$projectConfigListId /* Build configuration list for PBXProject ""$ProjectName"" */ = {"
Append-Line "			isa = XCConfigurationList;"
Append-Line "			buildConfigurations = ("
Append-Line "				$projectDebugId /* Debug */,"
Append-Line "				$projectReleaseId /* Release */,"
Append-Line "			);"
Append-Line "			defaultConfigurationIsVisible = 0;"
Append-Line "			defaultConfigurationName = Release;"
Append-Line "		};"
Append-Line "		$targetConfigListId /* Build configuration list for PBXNativeTarget ""$ProjectName"" */ = {"
Append-Line "			isa = XCConfigurationList;"
Append-Line "			buildConfigurations = ("
Append-Line "				$targetDebugId /* Debug */,"
Append-Line "				$targetReleaseId /* Release */,"
Append-Line "			);"
Append-Line "			defaultConfigurationIsVisible = 0;"
Append-Line "			defaultConfigurationName = Release;"
Append-Line "		};"
Append-Line "/* End XCConfigurationList section */"

Append-Line "	};"
Append-Line "	rootObject = $projectId /* Project object */;"
Append-Line "}"

New-Item -ItemType Directory -Path $projectDir -Force | Out-Null
[System.IO.File]::WriteAllText((Join-Path $projectDir "project.pbxproj"), $sb.ToString(), (New-Object System.Text.UTF8Encoding($false)))

# ---------------------------------------------------------------- scheme
New-Item -ItemType Directory -Path $schemeDir -Force | Out-Null

$buildableReference = @"
            <BuildableReference
               BuildableIdentifier = "primary"
               BlueprintIdentifier = "$targetId"
               BuildableName = "$ProjectName.app"
               BlueprintName = "$ProjectName"
               ReferencedContainer = "container:$ProjectName.xcodeproj">
            </BuildableReference>
"@

$schemeXml = @"
<?xml version="1.0" encoding="UTF-8"?>
<Scheme
   LastUpgradeVersion = "1530"
   version = "1.7">
   <BuildAction
      parallelizeBuildables = "YES"
      buildImplicitDependencies = "YES">
      <BuildActionEntries>
         <BuildActionEntry
            buildForTesting = "YES"
            buildForRunning = "YES"
            buildForProfiling = "YES"
            buildForArchiving = "YES"
            buildForAnalyzing = "YES">
$buildableReference
         </BuildActionEntry>
      </BuildActionEntries>
   </BuildAction>
   <TestAction
      buildConfiguration = "Debug"
      selectedDebuggerIdentifier = "Xcode.DebuggerFoundation.Debugger.LLDB"
      selectedLauncherIdentifier = "Xcode.DebuggerFoundation.Launcher.LLDB"
      shouldUseLaunchSchemeArgsEnv = "YES">
      <Testables>
      </Testables>
   </TestAction>
   <LaunchAction
      buildConfiguration = "Debug"
      selectedDebuggerIdentifier = "Xcode.DebuggerFoundation.Debugger.LLDB"
      selectedLauncherIdentifier = "Xcode.DebuggerFoundation.Launcher.LLDB"
      launchStyle = "0"
      useCustomWorkingDirectory = "NO"
      ignoresPersistentStateOnLaunch = "NO"
      debugDocumentVersioning = "YES"
      debugServiceExtension = "internal"
      allowLocationSimulation = "YES">
      <BuildableProductRunnable
         runnableDebuggingMode = "0">
$buildableReference
      </BuildableProductRunnable>
   </LaunchAction>
   <ProfileAction
      buildConfiguration = "Release"
      shouldUseLaunchSchemeArgsEnv = "YES"
      savedToolIdentifier = ""
      useCustomWorkingDirectory = "NO"
      debugDocumentVersioning = "YES">
      <BuildableProductRunnable
         runnableDebuggingMode = "0">
$buildableReference
      </BuildableProductRunnable>
   </ProfileAction>
   <AnalyzeAction
      buildConfiguration = "Debug">
   </AnalyzeAction>
   <ArchiveAction
      buildConfiguration = "Release"
      revealArchiveInOrganizer = "YES">
   </ArchiveAction>
</Scheme>
"@

[System.IO.File]::WriteAllText((Join-Path $schemeDir "$Scheme.xcscheme"), $schemeXml, (New-Object System.Text.UTF8Encoding($false)))

Write-Output "Generated $projectDir"
Write-Output "Sources: $($swiftFiles.Count) swift files, $($assetCatalogs.Count) asset catalog(s)"
Write-Output "Target: $targetId  Scheme: $Scheme.xcscheme"
