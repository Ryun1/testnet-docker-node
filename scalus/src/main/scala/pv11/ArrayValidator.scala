package pv11

import scalus.*
import scalus.uplc.builtin.{Data, BuiltinArray, BuiltinList}
import scalus.uplc.builtin.Data.{FromData, ToData}
import scalus.uplc.builtin.Builtins.*
import scalus.cardano.onchain.plutus.prelude.*
import scalus.cardano.onchain.plutus.v3.*

/** CIP-138: Array Type validator Example
  *
  * Datum is a Plutus Data list of integers stored on-chain.
  * Redeemer specifies an index and expected value.
  * The validator converts the list to an array (O(1) access),
  * looks up the element at the given index, and asserts it
  * matches the expected value.
  *
  * Test case: Array [10, 20, 30, 40, 50], index 2, expect 30
  *
  * Note: Array builtins (listToArray, indexArray) are PV11 features.
  */

case class ArrayRedeemer(index: BigInt, expectedValue: BigInt) derives FromData, ToData

@Compile object ArrayRedeemer

@Compile
object ArrayValidator {
  inline def validate(scData: Data): Unit = {
    val ctx = scData.to[ScriptContext]
    ctx.scriptInfo match
      case ScriptInfo.SpendingScript(_, datum) =>
        val d = datum.getOrFail("Missing datum")
        // Decode datum as a Plutus Data list of integers
        val dataList: BuiltinList[Data] = unListData(d)
        // Convert to array for O(1) indexed access (CIP-138)
        val arr: BuiltinArray[Data] = listToArray(dataList)
        // Decode redeemer
        val r = ctx.redeemer.to[ArrayRedeemer]
        // Look up element and verify
        val element: Data = indexArray(arr, r.index)
        val value: BigInt = unIData(element)
        require(value == r.expectedValue, "Array element does not match expected value")
      case _ => fail("Not a spending script")
  }
}
