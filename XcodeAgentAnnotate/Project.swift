import ProjectDescription

// Personal prototype default; override with TUIST_ANNOTATE_DEVELOPMENT_TEAM when generating.
let team = Environment.annotateDevelopmentTeam.getString(default: "3JZ7RUJD4Q")
let settings: Settings = .settings(base: [
    "DEVELOPMENT_TEAM": .string(team),
    "CODE_SIGN_STYLE": "Automatic",
    "SWIFT_VERSION": "5.0",
    "ENABLE_USER_SCRIPT_SANDBOXING": "NO",
])

let project = Project(
    name: "XcodeAgentAnnotate",
    settings: settings,
    targets: [
        .target(
            name: "XcodeAgentAnnotate",
            destinations: .macOS,
            product: .app,
            bundleId: "dev.tuist.XcodeAgentAnnotate",
            deploymentTargets: .macOS("14.0"),
            infoPlist: .extendingDefault(
                with: [
                    "CFBundleDisplayName": "Annotate for Agent",
                    "CFBundleURLTypes": [[
                        "CFBundleURLName": "dev.tuist.XcodeAgentAnnotate.capture",
                        "CFBundleURLSchemes": ["xcode-agent-annotate"],
                    ]],
                    "LSUIElement": true,
                ]
            ),
            sources: ["XcodeAgentAnnotate/Sources/**", "Shared/**"],
            resources: ["XcodeAgentAnnotate/Resources/**"],
            scripts: [
                .post(path: "Scripts/embed-xcodekit.sh", arguments: "containing-app",
                      name: "Preserve XcodeKit signature after extension embedding",
                      basedOnDependencyAnalysis: false),
            ],
            dependencies: [.target(name: "AnnotateEditorExtension")],
            settings: .settings(base: [
                "ENABLE_APP_SANDBOX": "NO",
                "CODE_SIGN_IDENTITY": "Apple Development",
            ])
        ),
        .target(
            name: "AnnotateEditorExtension",
            destinations: .macOS,
            product: .appExtension,
            bundleId: "dev.tuist.XcodeAgentAnnotate.EditorExtension",
            deploymentTargets: .macOS("14.0"),
            infoPlist: .extendingDefault(with: [
                "CFBundleDisplayName": "Annotate for Agent",
                "NSExtension": [
                    "NSExtensionPointIdentifier": "com.apple.dt.Xcode.extension.source-editor",
                    "NSExtensionAttributes": [
                        "XCSourceEditorExtensionPrincipalClass": "$(PRODUCT_MODULE_NAME).SourceEditorExtension",
                        "XCSourceEditorCommandDefinitions": [[
                            "XCSourceEditorCommandClassName": "$(PRODUCT_MODULE_NAME).CopyCodeCommand",
                            "XCSourceEditorCommandIdentifier": "dev.tuist.XcodeAgentAnnotate.copyCode",
                            "XCSourceEditorCommandName": "Copy Code with Message",
                        ]],
                    ],
                ],
            ]),
            sources: ["EditorExtension/Sources/**", "Shared/**"],
            entitlements: .file(path: "EditorExtension/EditorExtension.entitlements"),
            scripts: [
                .post(path: "Scripts/embed-xcodekit.sh", name: "Embed Apple-signed XcodeKit",
                      basedOnDependencyAnalysis: false),
            ],
            dependencies: [.sdk(name: "XcodeKit", type: .framework)],
            settings: .settings(base: [
                // Tuist's generic .appExtension needs Xcode's source-editor bootstrap.
                // Match com.apple.product-type.xcode-extension in Xcode's product spec.
                "LD_ENTRY_POINT": "_XCExtensionMain",
                "PRODUCT_SPECIFIC_LDFLAGS": "$(inherited) -lXcodeExtension",
                "LIBRARY_SEARCH_PATHS": "$(inherited) $(DEVELOPER_DIR)/usr/lib",
                "FRAMEWORK_SEARCH_PATHS": "$(inherited) $(DEVELOPER_DIR)/Library/Frameworks",
                "LD_RUNPATH_SEARCH_PATHS": "$(inherited) @executable_path/../Frameworks",
                "ENABLE_APP_SANDBOX": "YES",
                "CODE_SIGN_IDENTITY": "Apple Development",
            ])
        ),
        .target(
            name: "XcodeAgentAnnotateTests",
            destinations: .macOS,
            product: .unitTests,
            bundleId: "dev.tuist.XcodeAgentAnnotateTests",
            deploymentTargets: .macOS("14.0"),
            infoPlist: .default,
            sources: ["XcodeAgentAnnotate/Tests/**", "Shared/**"],
            dependencies: []
        ),
    ]
)
