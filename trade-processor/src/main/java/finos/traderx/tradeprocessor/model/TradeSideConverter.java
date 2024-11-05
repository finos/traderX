package finos.traderx.tradeprocessor.model;

import jakarta.persistence.AttributeConverter;
import jakarta.persistence.Converter;

@Converter
public class TradeSideConverter implements AttributeConverter<
    traderx.morphir.rulesengine.models.TradeSide.TradeSide, String> {

  @Override
  public String convertToDatabaseColumn(
      traderx.morphir.rulesengine.models.TradeSide.TradeSide object) {
    return object.getClass().getName();
  }

  @Override
  public traderx.morphir.rulesengine.models.TradeSide.TradeSide
  convertToEntityAttribute(String json) {
    try {
      return (traderx.morphir.rulesengine.models.TradeSide.TradeSide)Class
          .forName(json)
          .getDeclaredConstructor()
          .newInstance();
    } catch (Exception e) {
      return null;
    }
  }
}
