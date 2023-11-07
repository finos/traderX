package morphir.sdk

trait DecimalModuleCompat {
  import DecimalModuleCompat._
  implicit def toBigDecimalOps(value: BigDecimal): BigDecimalOps =
    new BigDecimalOps(value)
}

object DecimalModuleCompat {
  class BigDecimalOps(private val self: BigDecimal) extends AnyVal {
    def compareTo(that: BigDecimal): Int =
      self.compare(that)
  }
}
