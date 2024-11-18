package finos.traderx.tradeprocessor;

import finos.traderx.tradeprocessor.annotations.Validate;
import java.lang.reflect.Method;
import java.util.UUID;
import morphir.sdk.Maybe;
import morphir.sdk.Result;
import org.aspectj.lang.ProceedingJoinPoint;
import org.aspectj.lang.annotation.Around;
import org.aspectj.lang.annotation.Aspect;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Component;
import traderx.morphir.rulesengine.models.Errors.ErrResponse;
import traderx.morphir.rulesengine.models.Errors.Errors;
import traderx.morphir.rulesengine.models.TradeOrder.TradeOrder;

@Component
@Aspect
public class MorphirAspect {
  static Logger lg = LoggerFactory.getLogger(MorphirAspect.class);

  @Around(value = "@annotation(annotation)")
  public Object validateAction(ProceedingJoinPoint joinPoint,
                               Validate annotation) throws Throwable {

    lg.info("Validate with business rules");

    // fetch arguments from annotated methods
    Object[] args = joinPoint.getArgs();
    TradeOrder order = (TradeOrder)args[0];

    // TMP: way around json serialization issues, should fix
    order = new TradeOrder(
        UUID.randomUUID().toString().replaceAll("-", "").substring(0, 15),
        // order.state(),
        traderx.morphir.rulesengine.models.TradeState.New(), order.security(),
        order.quantity(), order.accountId(),
        traderx.morphir.rulesengine.models.TradeSide.BUY(),
        // order.side(),
        traderx.morphir.rulesengine.models.DesiredAction.BUYSTOCK(),
        // order.filled()
        new Maybe.Just<>(1)

    );

    lg.info(String.format("order: %s", order.toString()));

    Result<String, Object> result =
        traderx.morphir.rulesengine.TradingRules.processTrade(order);

    if (result.isErr()) {

      // cast to error
      var err = (morphir.sdk.Result.Err)result;
      String reason = err.error().toString();
      lg.error(String.format("Failed Morphir Validation Checks. Reason [%s]",
                             reason));

      throw new Exception(reason);
    }

    lg.info("Passed Morphir Validation Checks");

    return joinPoint.proceed();
  }
}
