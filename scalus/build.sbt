val scalusVersion = "0.15.0"

ThisBuild / scalaVersion := "3.3.7"
ThisBuild / scalacOptions ++= Seq("-feature", "-deprecation", "-unchecked")

addCompilerPlugin("org.scalus" %% "scalus-plugin" % scalusVersion)

lazy val root = (project in file("."))
  .settings(
    name := "pv11-validators",
    libraryDependencies ++= Seq(
      "org.scalus" %% "scalus" % scalusVersion,
      "org.scalus" %% "scalus-cardano-ledger" % scalusVersion,
      "org.scalus" %% "scalus-testkit" % scalusVersion % Test,
      "org.scalatest" %% "scalatest" % "3.2.19" % Test,
      "org.scalatestplus" %% "scalacheck-1-18" % "3.2.19.0" % Test
    )
  )
