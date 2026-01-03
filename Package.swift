// swift-tools-version: 5.9
import PackageDescription

let package = Package(
  name: "FitnessRatingEngine",
  products: [
    .library(name: "FitnessRatingEngine", targets: ["FitnessRatingEngine"]),
  ],
  targets: [
    .target(
      name: "FitnessRatingEngine",
      path: "HabitQuest/Core/FitnessRating"
    ),
    .testTarget(
      name: "FitnessRatingEngineTests",
      dependencies: ["FitnessRatingEngine"],
      path: "Tests/FitnessRatingEngineTests"
    ),
  ]
)

