pluginManagement { repositories { google(); mavenCentral(); gradlePluginPortal() } }
dependencyResolutionManagement { repositoriesMode.set(RepositoriesMode.FAIL_ON_PROJECT_REPOS); repositories { google(); mavenCentral() } }
rootProject.name = "KidRemoteParentLocal"
include(":app")
include(":child")
project(":child").projectDir = file("../child-android")

include(":accounting-storage")
project(":accounting-storage").projectDir = file("../child-android/accounting-storage")
