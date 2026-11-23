import finos.traderx.ordermatcher.service.OrderMatcherService;
import finos.traderx.ordermatcher.service.PricingNatsSubscriberService;
import static org.mockito.Mockito.*;
import static org.mockito.ArgumentMatchers.*;
public class MatcherProbe {
  public static void main(String[] args) throws Exception {
    var target=mock(OrderMatcherService.class);
    doAnswer(call->{System.out.println("LAB_RECEIVED "+call.getArgument(1));return null;}).when(target).onPriceTick(anyString(),any());
    var subscriber=new PricingNatsSubscriberService(target,System.getenv("NATS_ADDRESS"));
    subscriber.afterPropertiesSet();System.out.println("LAB_READY");
    try {while(System.in.read()!=-1) {}} finally {subscriber.destroy();}
  }
}
