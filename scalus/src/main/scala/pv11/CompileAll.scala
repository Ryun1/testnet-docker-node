package pv11

import scalus.compiler.Options
import scalus.uplc.PlutusV3
import scalus.uplc.PlutusV1
import java.nio.file.{Files, Path, Paths}

/** Compiles all PV11 validators and writes .plutus TextEnvelope JSON files.
  *
  * Usage: sbt run [output-dir]
  * Default output: ../plutus/pv11/
  */
object CompileAll {
  private given Options = Options.release

  lazy val expModCompiled = PlutusV3.compile(ExpModValidator.validate)
  lazy val arrayCompiled = PlutusV3.compile(ArrayValidator.validate)

  private def writeTextEnvelope(path: Path, plutusVersion: String, cborHex: String): Unit = {
    val json = s"""|{
                   |    "type": "$plutusVersion",
                   |    "description": "",
                   |    "cborHex": "$cborHex"
                   |}""".stripMargin
    Files.writeString(path, json + "\n")
  }

  def main(args: Array[String]): Unit = {
    val outputDir = if (args.nonEmpty) args(0) else "../plutus/pv11"
    Files.createDirectories(Paths.get(outputDir))

    println("Compiling ExpMod validator (CIP-109: Modular Exponentiation)...")
    val expModHex = expModCompiled.program.doubleCborHex
    writeTextEnvelope(
      Paths.get(s"$outputDir/expmod-validator.plutus"),
      "PlutusScriptV3",
      expModHex
    )
    println(s"  Written to $outputDir/expmod-validator.plutus")
    println(s"  Script size: ${expModCompiled.program.flatEncoded.length} bytes")

    println("Compiling Array validator (CIP-138: Array Type)...")
    val arrayHex = arrayCompiled.program.doubleCborHex
    writeTextEnvelope(
      Paths.get(s"$outputDir/array-validator.plutus"),
      "PlutusScriptV3",
      arrayHex
    )
    println(s"  Written to $outputDir/array-validator.plutus")
    println(s"  Script size: ${arrayCompiled.program.flatEncoded.length} bytes")

    println("Done! All validators compiled successfully.")
  }
}
