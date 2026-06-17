package pv11

import scalus.*
import scalus.uplc.builtin.Data
import scalus.uplc.builtin.Data.{FromData, ToData}
import scalus.uplc.builtin.Builtins.*
import scalus.cardano.onchain.plutus.prelude.*
import scalus.cardano.onchain.plutus.v3.*

/** CIP-109: Modular Exponentiation validator Example
  *
  * Datum contains base, exponent, modulus, and expected result.
  * The validator computes expModInteger(base, exponent, modulus)
  * and asserts the result equals the expected value.
  *
  * Test case: 3^5 mod 7 = 243 mod 7 = 5
  */

case class ExpModDatum(
    base: BigInt,
    exponent: BigInt,
    modulus: BigInt,
    expected: BigInt
) derives FromData, ToData

@Compile object ExpModDatum

@Compile
object ExpModValidator {
  inline def validate(scData: Data): Unit = {
    val ctx = scData.to[ScriptContext]
    ctx.scriptInfo match
      case ScriptInfo.SpendingScript(_, datum) =>
        val d = datum.getOrFail("Missing datum").to[ExpModDatum]
        val result = expModInteger(d.base, d.exponent, d.modulus)
        require(result == d.expected, "expModInteger result does not match expected")
      case _ => fail("Not a spending script")
  }
}
