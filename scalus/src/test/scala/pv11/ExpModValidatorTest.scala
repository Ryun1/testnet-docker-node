package pv11

import org.scalatest.funsuite.AnyFunSuite
import scalus.compiler
import scalus.compiler.Options
import scalus.testing.kit.ScalusTest
import scalus.uplc.builtin.Data.toData
import scalus.cardano.onchain.plutus.prelude.List

class ExpModValidatorTest extends AnyFunSuite with ScalusTest:

    given Options = compiler.defaultOptions
    val sir = compiler.compile(ExpModValidator.validate)

    test("ExpModValidator validates correct modular exponentiation via datum") {
        // 3^5 mod 7 = 243 mod 7 = 5
        val datum = ExpModDatum(
            base = 3,
            exponent = 5,
            modulus = 7,
            expected = 5
        )

        val context = makeSpendingScriptContext(
            datum = datum.toData,
            redeemer = ().toData,
            signatories = List()
        )

        val result = runScript(sir)(context)
        assert(result.isSuccess)
    }

    test("ExpModValidator fails when expected result is wrong") {
        // 3^5 mod 7 = 5, but we claim 6
        val datum = ExpModDatum(
            base = 3,
            exponent = 5,
            modulus = 7,
            expected = 6
        )

        val context = makeSpendingScriptContext(
            datum = datum.toData,
            redeemer = ().toData,
            signatories = List()
        )

        val result = runScript(sir)(context)
        assert(result.isFailure)
    }
