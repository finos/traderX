package finos.traderx.tradeprocessor.annotations;

import finos.traderx.tradeprocessor.model.TradeState;
import java.lang.annotation.ElementType;
import java.lang.annotation.Retention;
import java.lang.annotation.RetentionPolicy;
import java.lang.annotation.Target;

@Retention(RetentionPolicy.RUNTIME)
@Target(ElementType.METHOD)
public @interface Validate {
  TradeState attempt();
}
