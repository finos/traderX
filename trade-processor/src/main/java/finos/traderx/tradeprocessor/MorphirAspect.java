package finos.traderx.tradeprocessor;

import finos.traderx.tradeprocessor.annotations.Validate;
import morphir.sdk.Result;
import org.aspectj.lang.ProceedingJoinPoint;
import org.aspectj.lang.annotation.Around;
import org.aspectj.lang.annotation.Aspect;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Component;
import traderx.morphir.rulesengine.models.Error.Errors;
import traderx.morphir.rulesengine.models.TradeOrder.TradeOrder;

@Component
@Aspect
public class MorphirAspect {
  static Logger lg = LoggerFactory.getLogger(MorphirAspect.class);

  @Around(value = "@annotation(annotation)")
  public Object validateAction(ProceedingJoinPoint joinPoint,
                               Validate annotation) throws Throwable {

    lg.info("running validate");

    Object[] args = joinPoint.getArgs();
    TradeOrder order = (TradeOrder)args[0];

    switch (annotation.attempt().newInstance()) {
        case traderx.morphir.rulesengine.models.TradeState$TradeState$New$ cl -> {
                Result<Errors<Object>, Object> result = traderx.morphir.rulesengine.BuyRule.buyStock(order);
                if (result.isErr()) {
                    throw new Exception("Could not create new trade");
                }
                System.out.println("Reached New");
            }

            default -> throw new IllegalStateException("Unexpected value: " +
                    annotation.attempt());
        }
        return joinPoint.proceed();
    }
}
