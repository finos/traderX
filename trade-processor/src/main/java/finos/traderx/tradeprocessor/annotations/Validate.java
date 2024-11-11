package finos.traderx.tradeprocessor.annotations;

import java.lang.annotation.ElementType;
import java.lang.annotation.Retention;
import java.lang.annotation.RetentionPolicy;
import java.lang.annotation.Target;
import traderx.morphir.rulesengine.models.DesiredAction.DesiredAction;

@Retention(RetentionPolicy.RUNTIME)
@Target(ElementType.METHOD)
public @interface Validate {
  Class<? extends DesiredAction> desired();
}
